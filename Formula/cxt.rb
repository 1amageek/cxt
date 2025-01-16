class Cxt < Formula
    desc "Concatenate files with specified extension and copy to clipboard as markdown"
    homepage "https://github.com/1amageek/cxt"
    head "https://github.com/1amageek/cxt.git", branch: "main"
    
    depends_on :macos
    depends_on xcode: ["14.0", :build]
    
    def install
        system "swift", "build", "--disable-sandbox", "-c", "release"
        bin.install ".build/release/cxt"
    end
    
    test do
        system "#{bin}/cxt", "--version"
    end
end
