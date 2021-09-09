pkgs: with pkgs; with lib; with topology-lib;
let

  regions =  {
    a = { name = "eu-central-1";   # Europe (Frankfurt);
    };
    b = { name = "us-east-2";      # US East (Ohio)
    };
    # c = { name = "ap-southeast-1"; # Asia Pacific (Singapore)
    # };
    d = { name = "eu-west-2";      # Europe (London)
    };
    e = { name = "us-west-1";      # US West (N. California)
    };
    # f = { name = "ap-northeast-1"; # Asia Pacific (Tokyo)
    # };
  };

  bftNodes = [
    (mkBftCoreNode "a" 1
      { org = "IOHK";
        nodeId = 1;
        imports = let x = { nodeId = 1;}; in [{
          deployment.keys = {
            "utxo.vkey" = {
              keyFile = ../keys/utxo-keys + "/utxo${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "utxo.skey" = {
              keyFile = ../keys/utxo-keys + "/utxo${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
            "delegate.vkey" = {
              keyFile = ../keys/delegate-keys + "/delegate${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "delegate.skey" = {
              keyFile = ../keys/delegate-keys + "/delegate${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
            "genesis.vkey" = {
              keyFile = ../keys/genesis-keys + "/genesis${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "genesis.skey" = {
              keyFile = ../keys/genesis-keys + "/genesis${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
          };
        }];
      })
  ];

  nodes = with regions; map (composeAll [
    (withAutoRestartEvery 6)
  ]) (concatLists [
    (mkStakingPoolNodes "a" 1 "d" "IOGA1"
      { org = "IOHK";
        nodeId = 2;
        imports = let x = { nodeId = 2; }; in [{
          deployment.keys = {
            "utxo.vkey" = {
              keyFile = ../keys/utxo-keys + "/utxo${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "utxo.skey" = {
              keyFile = ../keys/utxo-keys + "/utxo${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
            "cold.vkey" = {
              keyFile = ../keys/node-keys + "/node-cold${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "cold.skey" = {
              keyFile = ../keys/node-keys + "/node-cold${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
            "node-vrf.vkey" = {
              keyFile = ../keys/node-keys + "/node-vrf${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "node-vrf.skey" = {
              keyFile = ../keys/node-keys + "/node-vrf${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
          };
        }];
      })
    (mkStakingPoolNodes "b" 2 "e" "IOGA2"
      { org = "IOHK"; nodeId = 3;
        imports = let x = { nodeId = 3; }; in [{
          deployment.keys = {
            "utxo.vkey" = {
              keyFile = ../keys/utxo-keys + "/utxo${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "utxo.skey" = {
              keyFile = ../keys/utxo-keys + "/utxo${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
            "cold.vkey" = {
              keyFile = ../keys/node-keys + "/node-cold${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "cold.skey" = {
              keyFile = ../keys/node-keys + "/node-cold${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
            "node-vrf.vkey" = {
              keyFile = ../keys/node-keys + "/node-vrf${toString x.nodeId}.vkey";
              destDir = "/root/keys";
            };
            "node-vrf.skey" = {
              keyFile = ../keys/node-keys + "/node-vrf${toString x.nodeId}.skey";
              destDir = "/root/keys";
            };
          };
        }];
      })
    # (mkStakingPoolNodes "c" 3 "f" "IOGA3" { org = "IOHK"; nodeId = 4; })
  ] ++ bftNodes);

  # test-node = {
  #   name = "test-node";
  #   nodeId = 99;
  #   org = "IOHK";
  #   region = "eu-central-1";
  #   producers = [
  #     "ioga1.relays.alonzo-purple.dev.cardano.org" "ioga1.relays.alonzo-white.dev.cardano.org"
  #     "ioga2.relays.alonzo-purple.dev.cardano.org" "ioga2.relays.alonzo-white.dev.cardano.org"
  #     "ioga3.relays.alonzo-purple.dev.cardano.org" "ioga3.relays.alonzo-white.dev.cardano.org"
  #   ];
  #   stakePool = false;
  #   public = false;
  # };

  relayNodes = (composeAll [
    connectWithThirdPartyRelays
    (regionalConnectGroupWith bftNodes)
    fullyConnectNodes
  ] (filter (n: !(n ? stakePool)) nodes));
  # ++ [
  #   test-node
  # ];

  coreNodes = filter (n: n ? stakePool) nodes;

in {

  inherit coreNodes relayNodes regions;

  # explorer = {
  #   containers = mapAttrs (b: _: {
  #     config = {
  #       services.cardano-graphql = {
  #         allowListPath = mkForce null;
  #         allowIntrospection = true;
  #       };
  #     };
  #   }) globals.explorerBackends;
  # };

  # smash = {
  #   services.cardano-node = {
  #     package = mkForce cardano-node;
  #   };
  # };

  # "${globals.faucetHostname}" = {
  #   services.cardano-faucet = {
  #     anonymousAccess = false;
  #     faucetLogLevel = "DEBUG";
  #     secondsBetweenRequestsAnonymous = 86400;
  #     secondsBetweenRequestsApiKeyAuth = 86400;
  #     lovelacesToGiveAnonymous = 1000000000;
  #     lovelacesToGiveApiKeyAuth = 10000000000;
  #     useByronWallet = false;
  #   };
  #   services.cardano-node = {
  #     package = mkForce cardano-node;
  #   };
  # };

  monitoring = {
    services.monitoring-services.publicGrafana = true;
    services.nginx.virtualHosts."monitoring.${globals.domain}".locations."/p" = {
      root = ../static/pool-metadata;
    };
  };

}
