pkgs: with pkgs; with lib; with topology-lib;
let

  regions = {
    a = { name = "eu-central-1";   /* Europe (Frankfurt)       */ };
    b = { name = "us-east-2";      /* US East (Ohio)           */ };
    c = { name = "ap-southeast-1"; /* Asia Pacific (Singapore) */ };
    d = { name = "eu-west-2";      /* Europe (London)          */ };
  };

  bftCoreNodes = let
    mkBftCoreNode = mkBftCoreNodeForRegions regions;
  in connectGroupWith (reverseList stakePoolNodes)
  (fullyConnectNodes [
    # OBFT centralized nodes recovery nodes
    (mkBftCoreNode "a" 1 {
      org = "IOHK";
      nodeId = 1;
    })
    # (mkBftCoreNode "b" 1 {
    #   org = "IOHK";
    #   nodeId = 2;
    # })
    # (mkBftCoreNode "c" 1 {
    #   org = "IOHK";
    #   nodeId = 3;
    # })
  ]);

  # FIXME: This setup is very brittle since the
  # `create-shelley-genesis-and-keys` script assumes the node id's are numbered
  # contigously. So make sure this is the case. We need to fix this.
  stakePoolNodes = let
    mkStakingPool = mkStakingPoolForRegions regions;
  in connectGroupWith bftCoreNodes
  (fullyConnectNodes [
    (mkStakingPool "d" 1 "IOHK1" { nodeId = 2; })
    # (mkStakingPool "e" 1 "IOHK2" { nodeId = 4; })
    # (mkStakingPool "f" 1 "IOHK3" { nodeId = 6; })
  ]);

  coreNodes = bftCoreNodes ++ stakePoolNodes;

  relayNodes = [];

in {
  inherit bftCoreNodes stakePoolNodes coreNodes relayNodes;
}