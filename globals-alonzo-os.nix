pkgs: with pkgs.iohkNix.cardanoLib; with pkgs.globals; {

  # This should match the name of the topology file.
  deploymentName = "alonzo-os";
  environmentName = "alonzo-os";

  withFaucet = false;
  withSmash = false;
  withCardanoDBExtended = false;
  withExplorer = false;
  withMonitoring = false;

  explorerBackends = {
    # a = explorer11;
  };
  explorerBackendsInContainers = true;

  environmentConfig = rec {
    relaysNew = "relays.${domain}";
    nodeConfig =
      pkgs.lib.recursiveUpdate
      environments.alonzo-qa.nodeConfig
      {
        ShelleyGenesisFile = ./keys/genesis.json;
        ShelleyGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/GENHASH);
        ByronGenesisFile = ./keys/byron/genesis.json;
        ByronGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/byron/GENHASH);
        AlonzoGenesisFile = ./keys/genesis.alonzo.json;
        AlonzoGenesisHash = builtins.replaceStrings ["\n"] [""] (builtins.readFile ./keys/ALONZOGENHASH);
        TestShelleyHardForkAtEpoch = 0;
        TestAllegraHardForkAtEpoch = 0;
        TestMaryHardForkAtEpoch = 0;
        TestAlonzoHardForkAtEpoch = 0;
        MaxKnownMajorProtocolVersion = 5;
        LastKnownBlockVersion-Major = 5;
      };
    explorerConfig = mkExplorerConfig environmentName nodeConfig;
  };

  # Every 5 hours
  relayUpdatePeriod = "0/5:00:00";

  ec2 = {
    credentials = {
      accessKeyIds = {
        IOHK = "default";
        dns = "dev";
      };
    };
  };
}
