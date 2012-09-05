require 'formula'

# NOTE: GCC 4.6.0 adds the gccgo compiler for the Go language. However,
# gccgo "is currently known to work on GNU/Linux and RTEMS. Solaris support
# is in progress. It may or may not work on other platforms."

def cxx?
  ARGV.include? '--enable-cxx'
end

def fortran?
  ARGV.include? '--enable-fortran'
end

def java?
  ARGV.include? '--enable-java'
end

def objc?
  ARGV.include? '--enable-objc'
end

def objcxx?
  ARGV.include? '--enable-objcxx'
end

def build_everything?
  ARGV.include? '--enable-all-languages'
end

def nls?
  ARGV.include? '--enable-nls'
end

def profiledbuild?
  ARGV.include? '--enable-profiled-build'
end

class Ecj < Formula
  # Little Known Fact: ecj, Eclipse Java Complier, is required in order to
  # produce a gcj compiler that can actually parse Java source code.
  url 'ftp://sourceware.org/pub/java/ecj-4.5.jar'
  md5 'd7cd6a27c8801e66cbaa964a039ecfdb'
end

class Gcc46 < Formula
  homepage 'http://gcc.gnu.org'
  url 'http://ftpmirror.gnu.org/gcc/gcc-4.6.3/gcc-4.6.3.tar.bz2'
  mirror 'http://ftp.gnu.org/gnu/gcc/gcc-4.6.3/gcc-4.6.3.tar.bz2'
  md5 '773092fe5194353b02bb0110052a972e'

  depends_on 'gmp'
  depends_on 'libmpc'
  depends_on 'mpfr'

  def patches
    { :p0 => ["http://gcc.gnu.org/bugzilla/attachment.cgi?id=25656"] }
  end

  def options
    [
      ['--enable-cxx', 'Build the g++ compiler'],
      ['--enable-fortran', 'Build the gfortran compiler'],
      ['--enable-java', 'Buld the gcj compiler'],
      ['--enable-objc', 'Enable Objective-C language support'],
      ['--enable-objcxx', 'Enable Objective-C++ language support'],
      ['--enable-all-languages', 'Enable all compilers and languages, except Ada'],
      ['--enable-nls', 'Build with natural language support'],
      ['--enable-profiled-build', 'Make use of profile guided optimization when bootstrapping GCC']
    ]
  end

  def install
    # Force 64-bit on systems that use it. Build failures reported for some
    # systems when this is not done.
    ENV.m64 if MacOS.prefer_64_bit?

    # GCC will suffer build errors if forced to use a particular linker.
    ENV.delete 'LD'

    ENV.remove_from_cflags '-Qunused-arguments'
    ENV.set_cpu_flags 'core2'

    # This is required on systems running a version newer than 10.6, and
    # it's probably a good idea regardless.
    #
    # https://trac.macports.org/ticket/27237
    ENV.append 'CXXFLAGS', '-U_GLIBCXX_DEBUG -U_GLIBCXX_DEBUG_PEDANTIC'

    gmp = Formula.factory 'gmp'
    mpfr = Formula.factory 'mpfr'
    libmpc = Formula.factory 'libmpc'

    # Sandbox the GCC lib, libexec and include directories so they don't wander
    # around telling small children there is no Santa Claus. This results in a
    # partially keg-only brew following suggestions outlined in the "How to
    # install multiple versions of GCC" section of the GCC FAQ:
    #     http://gcc.gnu.org/faq.html#multiple
    gcc_prefix = prefix + 'gcc'

    args = [
      # Sandbox everything...
      "--prefix=#{gcc_prefix}",
      # ...except the stuff in share...
      "--datarootdir=#{share}",
      # ...and the binaries...
      "--bindir=#{bin}",
      # ...which are tagged with a suffix to distinguish them.
      "--program-suffix=-#{version.to_s.slice(/\d\.\d/)}",
      "--with-gmp=#{gmp.prefix}",
      "--with-mpfr=#{mpfr.prefix}",
      "--with-mpc=#{libmpc.prefix}",
      "--with-system-zlib",
      "--enable-stage1-checking",
      "--enable-plugin",
      "--enable-lto",
      "--disable-multilib"
    ]

    args << '--disable-nls' unless nls?

    if build_everything?
      # Everything but Ada, which requires a pre-existing GCC Ada compiler
      # (gnat) to bootstrap. GCC 4.6.0 add go as a language option, but it is
      # currently only compilable on Linux.
      languages = %w[c c++ fortran java objc obj-c++]
    else
      # The C compiler is always built, but additional defaults can be added
      # here.
      languages = %w[c]

      languages << 'c++' if cxx?
      languages << 'fortran' if fortran?
      languages << 'java' if java?
      languages << 'objc' if objc?
      languages << 'obj-c++' if objcxx?
    end

    if java? or build_everything?
      source_dir = Pathname.new Dir.pwd

      Ecj.new.brew do |ecj|
        # Copying ecj.jar into the toplevel of the GCC source tree will cause
        # gcc to automagically package it into the installation. It *must* be
        # named ecj.jar and not ecj-version.jar in order for this to happen.
        mv "ecj-#{ecj.version}.jar", (source_dir + 'ecj.jar')
      end
    end

    Dir.mkdir 'build'
    Dir.chdir 'build' do
      system '../configure', "--enable-languages=#{languages.join(',')}", *args

      if profiledbuild?
        # Takes longer to build, may bug out. Provided for those who want to
        # optimise all the way to 11.
        system 'make profiledbootstrap'
      else
        system 'make bootstrap'
      end

      # At this point `make check` could be invoked to run the testsuite. The
      # deja-gnu and autogen formulae must be installed in order to do this.

      system 'make install'
    end
  end
end
