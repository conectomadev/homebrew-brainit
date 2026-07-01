class Brainit < Formula
  desc "Turn a local repo into code-embeddings docs + semantic vectors"
  homepage "https://www.brainit.dev"
  url "https://github.com/conectomadev/homebrew-brainit/releases/download/v0.1.0/brainit-cli.tar.gz"
  sha256 "bb4c205f707b285cbbed25b3eae5446e86da8145e298b2ae336615298a4845d9"
  license "MIT"

  depends_on "bun"

  def install
    libexec.install Dir["*"]
    cd libexec do
      system formula_opt_bin("bun")/"bun", "install", "--production"
    end
    (bin/"brainit").write <<~SH
      #!/bin/bash
      exec "#{formula_opt_bin("bun")}/bun" "#{libexec}/cli/index.ts" "$@"
    SH
    chmod 0755, bin/"brainit"
  end

  test do
    (testpath/"src").mkpath
    (testpath/"src/sample.ts").write("export function hi(){ return 1 }\n")
    system bin/"brainit", "--yes", "--out", "code-embeddings"
    assert_path_exists testpath/"code-embeddings/index.md"
  end
end
