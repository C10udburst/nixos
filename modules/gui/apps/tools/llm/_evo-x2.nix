let
  baseUrl = "https://evo-x2.brix0.wilkins.pl.eu.org/v1";

  # Thinking levels in increasing order; "off" is a pi-only key.
  levels = [
    "minimal"
    "low"
    "medium"
    "high"
    "xhigh"
    "max"
  ];

  # omp: thinking.efforts is the ordered non-null levels and thinking.effortMap
  # is emitted only when a level maps to a differently named provider value.
  toOmpModel = m:
    {
      inherit
        (m)
        id
        name
        contextWindow
        maxTokens
        ;
    }
    // (
      if m ? input
      then {inherit (m) input;}
      else {}
    )
    // (
      if m ? effortMap
      then let
        efforts = builtins.filter (l: supported m l) levels;
        remapped = builtins.filter (l: supported m l && m.effortMap.${l} != l) levels;
      in {
        reasoning = true;
        thinking =
          {
            mode = "effort";
            inherit efforts;
          }
          // (
            if remapped == []
            then {}
            else {
              effortMap = builtins.listToAttrs (
                map (l: {
                  name = l;
                  value = m.effortMap.${l};
                })
                remapped
              );
            }
          );
      }
      else {}
    );

  # pi: thinkingLevelMap is the effortMap verbatim; nulls mark unsupported levels.
  toPiModel = m:
    {
      inherit
        (m)
        id
        name
        contextWindow
        maxTokens
        ;
    }
    // (
      if m ? input
      then {inherit (m) input;}
      else {}
    )
    // (
      if m ? effortMap
      then {
        reasoning = true;
        thinkingLevelMap = m.effortMap;
      }
      else {}
    );

  supported = m: l: m.effortMap.${l} or null != null;

  models = [
    {
      id = "deepseek-r1-distill-qwen-32b";
      name = "DeepSeek R1 Distill Qwen 32B (Q8_0)";
      contextWindow = 131072;
      maxTokens = 65536;
    }
    {
      id = "deepseek-v4-flash";
      name = "DeepSeek V4 Flash IQ2XXS (80.76 GiB) with DSpark speculative decoding";
      contextWindow = 131072;
      maxTokens = 32768;
      effortMap = {
        off = "none";
        xhigh = "xhigh";
        max = "max";
      };
    }
    {
      id = "deepseek-v4.1-flash";
      name = "DeepSeek V4.1 Flash UD-IQ1_M (140 GB + 203 GB streamed Engram table) with DSpark drafting, 1M context";
      contextWindow = 1048576;
      maxTokens = 32768;
      effortMap = {
        off = "none";
        xhigh = "xhigh";
        max = "max";
      };
    }
    {
      id = "deepseek-v4.1-flash-uncensored";
      name = "DeepSeek V4.1 Flash UD-IQ1_M Uncensored (runtime abliteration overlay, shared weights)";
      contextWindow = 1048576;
      maxTokens = 32768;
      effortMap = {
        off = "none";
        xhigh = "xhigh";
        max = "max";
      };
    }
    {
      id = "gemma4-it:e2b";
      name = "Gemma 4 IT e2b on the Ryzen AI NPU via OpenFlowLM - pareto optimal chat/tool calling model";
      contextWindow = 32768;
      maxTokens = 8192;
    }
    {
      id = "glm-5.3-flash";
      name = "GLM-5.3-Flash EXL3 (320B total, 18B active) with MTP speculative decoding & vision";
      contextWindow = 524288;
      maxTokens = 32768;
      input = [
        "text"
        "image"
      ];
      # Thinking cannot be switched off and GLM-5.3 only accepts "max".
      effortMap = {
        off = null;
        minimal = null;
        xhigh = "max";
        max = "max";
      };
    }
    {
      id = "glm-5.3-flash-uncensored";
      name = "GLM-5.3-Flash EXL3 Uncensored (320B, runtime refusal-direction ablit hook)";
      contextWindow = 524288;
      maxTokens = 32768;
      input = [
        "text"
        "image"
      ];
      effortMap = {
        off = null;
        minimal = null;
        xhigh = "max";
        max = "max";
      };
    }
    {
      id = "lfm2.5-8b-a1b";
      name = "LFM2.5 8B A1B (Q4_K_M)";
      contextWindow = 128000;
      maxTokens = 16384;
    }
    {
      id = "mimo-v2.6-flash-mopd";
      name = "MiMo V2.6 Flash MOPD mixed IQ2_XXS/XS + Q8 (309.8B) with vision, audio and video";
      contextWindow = 1048576;
      maxTokens = 32768;
      input = [
        "text"
        "image"
      ];
      effortMap = {
        off = "none";
        xhigh = "xhigh";
        max = "max";
      };
    }
    {
      id = "nanbeige4.1:3b";
      name = "NanBeige 4.1 3B on the Ryzen AI NPU via OpenFlowLM - pareto optimal chat/tool calling model";
      contextWindow = 32768;
      maxTokens = 8192;
    }
    {
      id = "qwen2.5-72b-instruct";
      name = "Qwen 2.5 72B Instruct (Q4_K_M)";
      contextWindow = 32768;
      maxTokens = 8192;
    }
    {
      id = "qwen3.8-27b";
      name = "Qwen 3.8 27B (UD-Q4_K_XL + DFlash2)";
      contextWindow = 32768;
      maxTokens = 8192;
      input = [
        "text"
        "image"
      ];
      effortMap = {
        off = "none";
        xhigh = "xhigh";
        max = "max";
      };
    }
    {
      id = "qwen3.8-flash-next";
      name = "Qwen 3.8 Flash Next (UD-Q4_K_XL + MTP)";
      contextWindow = 262144;
      maxTokens = 32768;
      input = [
        "text"
        "image"
      ];
      effortMap = {
        off = "none";
        xhigh = "xhigh";
        max = "max";
      };
    }
    {
      id = "qwen3.8-flash-next-uncensored";
      name = "Qwen 3.8 Flash Next Uncensored Q4 Mix with MTP speculative decoding & vision";
      contextWindow = 262144;
      maxTokens = 32768;
      input = [
        "text"
        "image"
      ];
      effortMap = {
        off = "none";
        xhigh = "xhigh";
        max = "max";
      };
    }
    {
      id = "ripple-65b";
      name = "Ripple-65B Preview AD-Q6_K - dense 65B agentic coder (SWA + NoPE, ricursive arch)";
      contextWindow = 262144;
      maxTokens = 16384;
    }
  ];
in {
  inherit baseUrl models;

  # Full ~/.pi/agent/models.json document for the "llm" provider.
  piJson = builtins.toJSON {
    providers.llm = {
      api = "openai-completions";
      apiKey = "none";
      baseUrl = baseUrl;
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = true;
      };
      models = map toPiModel models;
      name = "EVO-X2 LLM Gateway (llm:8080)";
    };
  };

  # Attribute set for the "llm" provider, rendered with pkgs.formats.yaml into
  # ~/.omp/agent/models.yml.
  ompRegistry = {
    providers.llm = {
      api = "openai-completions";
      # Gateway is unauthenticated; `auth: none` waives the apiKey requirement.
      auth = "none";
      baseUrl = baseUrl;
      compat = {
        supportsDeveloperRole = false;
        supportsReasoningEffort = true;
      };
      models = map toOmpModel models;
    };
  };
}
