{ lib
, stdenv
, python312
, python312Packages
, makeWrapper
, withClaudeCode ? false
, claude-code
, uv
, ripgrep
, git
, tmux
, xdg-utils
}:

let
  pyPkgs = python312Packages;
  buildPythonApplication = pyPkgs.buildPythonApplication;
  runtimePackages = lib.optionals withClaudeCode [
    claude-code
  ] ++ [
    uv
    ripgrep
    git
    tmux
    xdg-utils
  ];
in
buildPythonApplication rec {
  pname = "opengauss";
  version = "0.2.2";
  pyproject = true;
  python = python312;

  src = lib.cleanSource ../.;

  nativeBuildInputs = [
    makeWrapper
  ];

  build-system = with pyPkgs; [
    setuptools
    wheel
  ];

  dependencies = with pyPkgs; [
    openai
    anthropic
    python-dotenv
    fire
    httpx
    rich
    tenacity
    pyyaml
    requests
    jinja2
    pydantic
    prompt-toolkit
  ];

  pythonImportsCheck = [
    "gauss_cli.main"
    "cli"
    "run_agent"
  ];

  postInstall = ''
    mkdir -p $out/share/opengauss/website/docs/getting-started
    cp README.md $out/share/opengauss/README.md
    cp website/docs/getting-started/start-here.md \
      $out/share/opengauss/website/docs/getting-started/start-here.md

    cat > $out/bin/gauss-open-guide <<EOF
    #!${stdenv.shell}
    set -euo pipefail
    guide_path="$out/share/opengauss/website/docs/getting-started/start-here.md"
    if [ ! -f "\$guide_path" ]; then
      printf '%s\n' "Guide not found: \$guide_path" >&2
      exit 1
    fi
    if command -v xdg-open >/dev/null 2>&1; then
      exec xdg-open "\$guide_path"
    elif command -v open >/dev/null 2>&1; then
      exec open "\$guide_path"
    fi
    printf '%s\n' "\$guide_path"
    EOF
    chmod +x $out/bin/gauss-open-guide
  '';

  postFixup = ''
    runtime_path='${lib.makeBinPath runtimePackages}'
    for prog in $out/bin/gauss $out/bin/gauss-agent $out/bin/gauss-acp; do
      if [ -x "$prog" ]; then
        wrapProgram "$prog" \
          --prefix PATH : "$runtime_path" \
          --set-default GAUSS_INSTALL_ROOT "$out/share/opengauss"
      fi
    done
  '';

  installCheckPhase = ''
    runHook preInstallCheck
    export HOME="$(mktemp -d)"
    $out/bin/gauss version >/dev/null
    $out/bin/gauss-open-guide >/dev/null
    runHook postInstallCheck
  '';

  meta = {
    description = "Open Gauss Lean workflow orchestrator";
    homepage = "https://github.com/Neuron-Group/OpenGaussNix";
    mainProgram = "gauss";
    license = lib.licenses.mit;
    platforms = lib.platforms.linux ++ lib.platforms.darwin;
  };
}
