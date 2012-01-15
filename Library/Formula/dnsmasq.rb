require 'formula'
require 'socket'

class DnsmasqConf < GithubGistFormula
  url 'https://raw.github.com/gist/1613339/ff9287cab82aa8dd83127a44d86f14bf3366fbe7/dnsmasq.conf'
  md5 'e35a7ebfd9738067940ff338123766ea'
end

class LocalWildcardResolver < GithubGistFormula
  url 'https://raw.github.com/gist/1613339/c1e91ac0ed7260a9c2b97e79b9772e22415e8bbc/local_wildcard'
  md5 'a9a2093fd25c2d2815c35ad950b39995'
end

class Dnsmasq < Formula
  url 'http://www.thekelleys.org.uk/dnsmasq/dnsmasq-2.57.tar.gz'
  homepage 'http://www.thekelleys.org.uk/dnsmasq/doc.html'
  md5 'd10faeb409717eae94718d7716ca63a4'

  def options
    [
      ['--with-idn', "Compile with IDN support"],
    ]
  end

  depends_on "libidn" if ARGV.include? '--with-idn'

  def la; Pathname.new(File.expand_path("~/Library/LaunchAgents")); end
  def plist; "uk.org.thekelleys.dnsmasq.plist"; end

  def install
    ENV.deparallelize

    # Fix etc location
    inreplace "src/config.h", "/etc/dnsmasq.conf", "#{etc}/dnsmasq.conf"

    # Optional IDN support
    if ARGV.include? '--with-idn'
      inreplace "src/config.h", "/* #define HAVE_IDN */", "#define HAVE_IDN"
    end

    # Fix compilation on Lion
    ENV.append_to_cflags "-D__APPLE_USE_RFC_3542" if 10.7 <= MACOS_VERSION
    inreplace "Makefile" do |s|
      s.change_make_var! "CFLAGS", ENV.cflags
    end

    system "make install PREFIX=#{prefix}"

    (prefix+plist).write startup_plist
    (prefix+plist).chmod 0644

    DnsmasqConf.new.brew do |f|
      inreplace 'dnsmasq.conf', '#{hostname}', Socket.gethostname
      etc.install 'dnsmasq.conf'
    end
    
    system "cp #{prefix+plist} #{la}"
    system "launchctl unload -w #{la+plist}"
    system "launchctl load -w #{la+plist}"

    LocalWildcardResolver.new.brew do |f|
      inreplace 'local_wildcard', '#{hostname}', Socket.gethostname
      system "sudo mkdir -p /etc/resolver && sudo cp local_wildcard /etc/resolver/ && sudo killall mDNSResponder"
    end
  end

  def caveats; <<-EOS.undent
    You can test wildcard domain resolution with:
      ping -c 1 -W 1 any.subdomain.of.#{Socket.gethostname}
    EOS
  end

  def startup_plist; <<-EOS.undent
    <?xml version="1.0" encoding="UTF-8"?>
    <!DOCTYPE plist PUBLIC "-//Apple Computer//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
    <plist version="1.0">
      <dict>
        <key>Label</key>
        <string>uk.org.thekelleys.dnsmasq</string>
        <key>ProgramArguments</key>
        <array>
          <string>#{sbin+"dnsmasq"}</string>
          <string>--keep-in-foreground</string>
        </array>
        <key>KeepAlive</key>
        <dict>
          <key>NetworkState</key>
          <true/>
        </dict>
        <key>WorkingDirectory</key>
        <string>#{HOMEBREW_PREFIX}</string>
      </dict>
    </plist>
    EOS
  end
end
