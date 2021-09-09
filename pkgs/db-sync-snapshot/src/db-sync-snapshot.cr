#!/usr/bin/env nix-shell
#!nix-shell -i crystal -p crystal -I nixpkgs=/nix/store/3b6p06fazphgdzwkf9g75l0pwsm5dnj8-source

# Crystal v0.34 source path for `-I nixpkgs=` is from:
#   nix-instantiate --eval -E '((import ../nix/sources.nix).nixpkgs-crystal).outPath'

# This script can be used in cron.  For example:
# 00 16 * * * cd ~/$CLUSTER && nix-shell --run 'node-update -r --all' -I nixpkgs="$(nix eval '(import ./nix {}).path')" \
#   &> db-sync-snapshot/logs/db-sync-snapshot-$(date -u +"\%F_\%H-\%M-\%S").log

require "json"
require "email"
require "option_parser"
require "http/client"
require "file_utils"

PATH_MOD                = ENV.fetch("PATH_MOD", ".")

EMAIL_FROM              = "devops@ci.iohkdev.io"
NOW                     = Time.utc.to_s("%F %R %z")

SNAPSHOT_WORK_DIR       = "./db-sync-snapshot"

IO_CMD_OUT    = IO::Memory.new
IO_CMD_ERR    = IO::Memory.new
IO_TEE_FULL   = IO::Memory.new
IO_TEE_OUT    = IO::MultiWriter.new(IO_CMD_OUT, IO_TEE_FULL, STDOUT)
IO_TEE_ERR    = IO::MultiWriter.new(IO_CMD_ERR, IO_TEE_FULL, STDERR)
IO_TEE_STDOUT = IO::MultiWriter.new(IO_TEE_FULL, STDOUT)
IO_NO_TEE_OUT = IO::MultiWriter.new(IO_CMD_OUT, STDOUT)
IO_NO_TEE_ERR = IO::MultiWriter.new(IO_CMD_ERR, STDERR)

class DbSyncSnapshot

  @sesUsername : String
  @sesSecret : String
  @cluster : String
  @s3Bucket : String
  @emails : Array(String)

  def initialize(@emailOpt : String)

    if (@emailOpt != "")
      @emails = @emailOpt.split(',')
      if runCmdSecret("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.username'").success?
        @sesUsername = IO_CMD_OUT.to_s.strip('"')
      else
        abort("Unable to process the ses username.")
      end

      if runCmdSecret("nix-instantiate --eval -E --json '(import #{PATH_MOD}/static/ses.nix).sesSmtp.secret'").success?
        @sesSecret = IO_CMD_OUT.to_s.strip('"')
      else
        abort("Unable to process the ses secret.")
      end
    else
      @emails = [] of String
      @sesUsername = ""
      @sesSecret = ""
    end

    if runCmdVerbose("nix-instantiate --eval -E --json '(import #{PATH_MOD}/nix {}).globals.environmentName'").success?
      @cluster = IO_CMD_OUT.to_s.strip('"')
    else
      updateAbort("Unable to process the environment name from the globals file.")
    end

    if runCmdVerbose("nix-instantiate --eval -E --json '(import #{PATH_MOD}/nix {}).globals.dbSyncSnapshotS3Bucket'").success?
      @s3Bucket = IO_CMD_OUT.to_s.strip('"')
    else
      updateAbort("Unable to process the s3 bucket name name from the globals file (`dbSyncSnapshotS3Bucket` attribute).")
    end

  end

  def runCmd(cmd) : Process::Status
    if (@noSensitiveOpt)
      runCmdSensitive(cmd)
    else
      runCmdVerbose(cmd)
    end
  end

  def runCmd(cmd, output, error)
    IO_CMD_OUT.clear
    IO_CMD_ERR.clear
    IO_TEE_STDOUT.puts "+ #{cmd}"
    Process.run(cmd, output: output, error: error, shell: true)
  end

  def runCmdVerbose(cmd): Process::Status
    result = runCmd(cmd, IO_TEE_OUT, IO_TEE_ERR)
    IO_TEE_STDOUT.puts "\n"
    result
  end

  def runCmdSensitive(cmd) : Process::Status
    runCmd(cmd, IO_NO_TEE_OUT, IO_NO_TEE_ERR)
  end

  def runCmdSecret(cmd) : Process::Status
    runCmd(cmd, IO_CMD_OUT, IO_NO_TEE_ERR)
  end

  def updateAbort(msg)
    msg = "Cardano-db-sync snapshot upload aborted on #{@cluster} at #{NOW}:\n" \
          "MESSAGE: #{msg}\n" \
          "STDOUT: #{IO_CMD_OUT}\n" \
          "STDERR: #{IO_CMD_ERR}"
    if (@emailOpt != "")
      sendEmail("Cardano-db-sync snapshot upload ABORTED on #{@cluster} at #{NOW}", "#{msg}\n\nFULL LOG:\n#{IO_TEE_FULL}")
    else
      IO_TEE_OUT.puts msg
    end
    exit(1)
  end

  def sendEmail(subject, body)
    config = EMail::Client::Config.new("email-smtp.us-east-1.amazonaws.com", 25)
    config.use_tls(EMail::Client::TLSMode::STARTTLS)
    config.tls_context
    config.tls_context.add_options(OpenSSL::SSL::Options::NO_SSL_V2 | OpenSSL::SSL::Options::NO_SSL_V3 | OpenSSL::SSL::Options::NO_TLS_V1 | OpenSSL::SSL::Options::NO_TLS_V1_1)
    config.use_auth("#{@sesUsername}", "#{@sesSecret}")
    client = EMail::Client.new(config)
    client.start do
      @emails.each do |rcpt|
        email = EMail::Message.new
        email.from(EMAIL_FROM)
        email.to(rcpt)
        email.subject(subject)
        email.message(body)
        send(email)
      end
    end
  end

  def retrieveSnapshot()

    if runCmdVerbose("nixops ssh explorer 'cd /var/lib/cexplorer && ls -tr db-sync-snapshot*.tgz | head -n 1'").success?
      snapshotFile = IO_CMD_OUT.to_s.chomp

      if !runCmdVerbose("mkdir -p #{SNAPSHOT_WORK_DIR} "\
        "&& nixops scp --from explorer /var/lib/cexplorer/#{snapshotFile} #{SNAPSHOT_WORK_DIR}/").success?
        updateAbort("Could not retrieve db-sync snasphot from explorer.")
      end
      snapshotFile
    else
      updateAbort("Unable to find a snapshot file in explorer /var/lib/cexplorer directory.")
    end

  end

  def uploadSnapshot(snapshotFile)
    matchMajorVersion = /-schema-(\d+)-/.match(snapshotFile)
    if matchMajorVersion == nil
      updateAbort("Could not deduce db-sync major version from snapshot file name: #{snapshotFile}")
    else
      majorVersion = matchMajorVersion.try &.[1]
      if !runCmdVerbose("./scripts/upload-with-checksum.sh #{SNAPSHOT_WORK_DIR}/#{snapshotFile} #{@s3Bucket} cardano-db-sync/#{majorVersion}").success?
        updateAbort("Error while upload db-sync snasphot.")
      end
      IO_CMD_OUT.to_s
    end
  end

  def run()

    IO_TEE_OUT.puts "Script options selected:"
    IO_TEE_OUT.puts "s3Bucket = #{@s3Bucket}"
    IO_TEE_OUT.puts "emailOpt = #{@emailOpt}"

    snapshotFile = retrieveSnapshot()
    uploadLog = uploadSnapshot(snapshotFile)

    IO_TEE_OUT.puts "Cardano-db-sync snapshot upload on cluster #{@cluster} at #{NOW}, completed."
    if (@emailOpt != "")
      sendEmail("Cardano-db-sync snapshot upload on cluster #{@cluster} at #{NOW}, completed.", uploadLog)
    end
  end
end

emailOpt = ""
OptionParser.parse do |parser|
  parser.banner = "Usage: db-sync-snapshot [arguments]"
  parser.on("-e EMAIL", "--email EMAIL", "Send email(s) to given address(es) (comma separated) on script completion") { |email| emailOpt = email }

  parser.on("-h", "--help", "Show this help") do
    puts parser
    exit
  end
  parser.invalid_option do |flag|
    STDERR.puts "ERROR: #{flag} is not a valid option."
    STDERR.puts parser
    exit(1)
  end
end

dbSyncSnapshot = DbSyncSnapshot.new(emailOpt: emailOpt)

dbSyncSnapshot.run

exit 0
