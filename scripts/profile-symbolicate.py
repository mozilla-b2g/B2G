#!/usr/bin/python

import argparse, bisect, json, os, subprocess, sys

gSpecialLibs = {
    # The [vectors] is a special section used for functions which can really
    # only be implemented in kernel space. See arch/arm/kernel/entry-armv.S
    "[vectors]" : {
      "0xffff0f60": "__kernel_cmpxchg64",
      "0xffff0fa0": "__kernel_dmb",
      "0xffff0fc0": "__kernel_cmpxchg",
      "0xffff0fe0": "__kernel_get_tls",
      "0xffff0ffc": "__kernel_helper_version"
    }
}

###############################################################################
#
# Library class. There is an instance of this for each library in the profile.
#
###############################################################################

class Library:
  def __init__(self, lib_dict, verbose=False):
    """lib_dict will be the JSON dictionary from the profile"""
    self.start = lib_dict["start"]
    self.end = lib_dict["end"]
    self.offset = lib_dict["offset"]
    self.target_name = lib_dict["name"]
    self.verbose = verbose
    self.host_name = None
    self.located = False
    self.symbols = {}
    self.symbol_table = None
    self.symbol_table_addresses = None

  def AddressToSymbol(self, address_str):
    """Attempts to convert an address into a symbol."""
    return self.AddressesToSymbols([address_str])[0]

  def AddressesToSymbols(self, addresses_strs):
    """Converts multiple addresses into symbols."""
    if not self.located:
      self.Locate()
    if self.symbol_table:
      return self.LookupAddressesInSymbolTable(addresses_strs)
    if not self.host_name:
      unknown = "Unknown (in " + self.target_name + ")"
      return [unknown for i in range(len(addresses_strs))]
    if "TARGET_TOOLS_PREFIX" in os.environ:
      target_tools_prefix = os.environ["TARGET_TOOLS_PREFIX"]
    else:
      target_tools_prefix = "arm-eabi-"
    args = [target_tools_prefix + "addr2line", "-C", "-f", "-e", self.host_name]
    for address_str in addresses_strs:
      lib_address = int(address_str, 0) - self.start + self.offset
      if self.verbose:
        print "Address %s maps to library '%s' offset 0x%08x" % (address_str, self.host_name, lib_address)
      # Fix up addresses from stack frames; they're for the insn after
      # the call, which might be different function thanks to inlining:
      adj_address = (lib_address & ~1) - 1
      args.append("0x%08x" % adj_address)
    # Calling addr2line will return 2 lines for each address. The output will be something
    # like the following:
    #   PR_IntervalNow
    #   /home/work/B2G-profiler/mozilla-inbound/nsprpub/pr/src/misc/prinrval.c:43
    #   PR_Unlock
    #   /home/work/B2G-profiler/mozilla-inbound/nsprpub/pr/src/pthreads/ptsynch.c:191
    syms_and_lines = subprocess.check_output(args).split("\n")
    syms = []
    for i in range(len(addresses_strs)):
      syms.append(syms_and_lines[i*2] + " (in " + self.target_name + ")")
    return syms

  def AddUnresolvedAddress(self, address):
    """Stores an address into a set of addresses which will be translated into symbols later"""
    # The output format wants the addresses as 0xAAAAAAAA, so we store the keys as strings
    self.symbols["0x%08x" % address] = None

  def ContainsAddress(self, address):
    """Determines if the indicated address is contained in this library"""
    return (address >= self.start) and (address < self.end)

  def Dump(self):
    """Dumps out some information about this library."""
    self.Locate()
    print "0x%08x-0x%08x 0x%08x %-40s %s" % (self.start, self.end, self.offset, self.target_name, self.host_name)

  def DumpSymbols(self):
    """Dumps out some information about the symbols in this library."""
    for address_str in sorted(self.symbols.keys()):
      print address_str, self.symbols[address_str]

  def FindLibInTree(self, basename, dir, exclude_dir=None):
    """Search a tree for a library and return the first one found"""
    args = ["find", dir]
    if exclude_dir:
      args = args + ["!", "(", "-name", exclude_dir, "-prune", ")"]
    args = args + ["-name", basename, "-type", "f", "-print", "-quit"]
    fullname = subprocess.check_output(args)
    if len(fullname) > 0:
      if fullname[-1] == "\n":
        return fullname[:-1]
      return fullname
    return None

  def Locate(self):
    """Try to determine the local name of a given library"""
    if self.target_name[:7] == "/system":
      basename = os.path.basename(self.target_name)
      # First look for a gecko library. We avoid the dist tree since
      # those are stripped.
      if "GECKO_OBJDIR" in os.environ:
        gecko_objdir = os.environ["GECKO_OBJDIR"]
      else:
        gecko_objdir = "objdir-gecko"
      if not os.path.isdir(gecko_objdir):
        print(gecko_objdir, "isn't a directory");
        sys.exit(1)
      lib_name = self.FindLibInTree(basename, gecko_objdir, exclude_dir="dist")
      if not lib_name:
        # Probably an android library
        if "PRODUCT_OUT" in os.environ:
          product_out = os.environ["PRODUCT_OUT"] + "/symbols"
        else:
          product_out = "out/target/product"
        if not os.path.isdir(product_out):
          print(product_out, "isn't a directory");
          sys.exit(1)
        lib_name = self.FindLibInTree(basename, product_out)
      if lib_name:
        self.host_name = lib_name
        if self.verbose:
          print "Found '" + self.host_name + "' for '" + self.target_name + "'"
    elif self.target_name in gSpecialLibs:
      self.symbol_table = gSpecialLibs[self.target_name]
      self.symbol_table_addresses = sorted(self.symbol_table.keys())
    elif self.target_name[:1] == "/": # Absolute paths.
      basename = os.path.basename(self.target_name)
      dirname = os.path.dirname(self.target_name)
      lib_name = self.target_name
      if os.path.exists(lib_name):
        self.target_name = basename
        self.host_name = lib_name
        if self.verbose:
          print "Found '" + self.host_name + "' for '" + self.target_name + "'"
    self.located = True

  def LookupAddressInSymbolTable(self, address_str):
    """Lookup an address using a special symbol_table."""
    i = bisect.bisect(self.symbol_table_addresses, address_str)
    if i:
      i = i - 1
    if address_str >= self.symbol_table_addresses[i]:
      sym = self.symbol_table[self.symbol_table_addresses[i]]
    else:
      sym = "Unknown"
    return sym + " (in " + self.target_name + ")"

  def LookupAddressesInSymbolTable(self, addresses):
    """Looks up multiple addresses using the special symbol table."""
    syms = []
    for address in addresses:
      syms.append(self.LookupAddressInSymbolTable(address))
    return syms

  def ResolveSymbols(self, progress=False):
    """Tries to convert all of the symbols into symbolic equivalents."""
    if len(self.symbols) == 0:
      return
    addresses_strs = self.symbols.keys()
    for i in range(0,len(addresses_strs), 256):
      slice = addresses_strs[i:i+256]
      if progress:
        print "Resolving symbols for", self.target_name, len(slice), "addresses"
      syms = self.AddressesToSymbols(slice)
      for j in range(len(syms)):
        self.symbols[addresses_strs[i+j]] = syms[j]

###############################################################################
#
# Libraries class. Encapsulates the collection of libraries.
#
###############################################################################

class Libraries:
  def __init__(self, profile, verbose=False):
    lib_dicts = json.loads(profile["libs"])
    lib_dicts = sorted(lib_dicts, key=lambda lib: lib["start"])
    self.libs = [Library(lib_dict, verbose=verbose) for lib_dict in lib_dicts]
    # Create a sorted list of just the start addresses so that we can use
    # bisect to lookup addresses
    self.libs_start = [lib.start for lib in self.libs]
    self.profile = profile
    self.last_lib = None

  def Dump(self):
    """Dumps out some information about all of the libraries that we're tracking."""
    for lib in self.libs:
      lib.Dump()

  def DumpSymbols(self):
    """Dumps out the symbols for all of the libraries that we're tracking."""
    for lib in self.libs:
      lib.DumpSymbols()

  def AddressToLib(self, address):
    """Does a binary search through our ordered collection of libraries."""
    i = bisect.bisect(self.libs_start, address)
    if i:
      i = i - 1
    if i < len(self.libs_start):
      lib = self.libs[i]
      if lib.ContainsAddress(address):
        return lib

  def Lookup(self, address):
    """Figures out which library a given address comes from."""
    if not (self.last_lib and self.last_lib.ContainsAddress(address)):
      self.last_lib = self.AddressToLib(address)
    return self.last_lib

  def ResolveSymbols(self, progress=True):
    """Tries to convert all of the symbols into symbolic equivalents."""
    for lib in self.libs:
      lib.ResolveSymbols(progress=progress)

  def ScanLocations(self, progress=False):
    """Scans through the locations and builds a set of unresolved addresses for each library."""
    if progress:
      print "Scanning for unresolved addresses..."
    last_address = None
    for thread in self.profile["threads"]:
      samples = thread["samples"]
      for sample in samples:
        frames = sample["frames"]
        for frame in frames:
          address_str = frame["location"]
          if address_str[:2] == "0x":
            address = int(address_str, 0)
            # Quick optimization since lots of times the same address appears
            # many times in a row. We only need to add each address once.
            if address != last_address:
              lib = self.Lookup(address)
              if lib:
                lib.AddUnresolvedAddress(address)
                last_address = address

  def SymbolicationTable(self):
    """Create the union of all of the symbols from all of the libraries."""
    result = {}
    for lib in self.libs:
      result.update(lib.symbols)
    return result

###############################################################################
#
# Main
#
###############################################################################

def main():
  parser = argparse.ArgumentParser(description="Symbolicate Gecko Profiler file")
  parser.add_argument("filename", help="profile file from phone")
  parser.add_argument("--dump-libs", help="Dump library information", action="store_true")
  parser.add_argument("--dump-syms", help="Dump symbol information", action="store_true")
  parser.add_argument("--no-progress", help="Turn off progress messages", action="store_true")
  parser.add_argument("-l", "--lookup", help="lookup a single address")
  parser.add_argument("-o", "--output", help="specify the name of the output file")
  parser.add_argument("-v", "--verbose", help="increase output verbosity", action="store_true")
  args = parser.parse_args(sys.argv[1:])
  verbose = args.verbose
  progress = not args.no_progress

  if "GECKO_OBJDIR" not in os.environ:
    print "'GECKO_OBJDIR' needs to be defined in the environment"
    sys.exit(1)

  if "TARGET_TOOLS_PREFIX" not in os.environ:
    print "'TARGET_TOOLS_PREFIX' needs to be defined in the environment"
    sys.exit(1)

  if "PRODUCT_OUT" not in os.environ:
    print "'PRODUCT_OUT' needs to be defined in the environment"
    sys.exit(1)

  if verbose:
    print "Filename =", args.filename
    print "GECKO_OBJDIR = '" + os.environ["GECKO_OBJDIR"] + "'"
    print "TARGET_TOOLS_PREFIX = '" + os.environ["TARGET_TOOLS_PREFIX"] + "'"
    print "PRODUCT_OUT = '" + os.environ["PRODUCT_OUT"] + "'"

  # Read in the JSON file created by the profiler.
  if progress:
    print "Reading profiler file", args.filename, "..."
  profile = json.load(open(args.filename, "rb"))

  libs = Libraries(profile, verbose)
  if args.dump_libs:
    libs.Dump()

  if args.lookup:
    address_str = args.lookup
    address = int(address_str, 0)
    lib = libs.Lookup(address)
    if lib:
      lib.Locate()
      print("Address 0x%08x maps to symbol '%s'" % (address, lib.AddressToSymbol(address_str)))
    else:
      print("Address 0x%08x not found in a library" % address)
  else:
    libs.ScanLocations(progress=progress)
    libs.ResolveSymbols(progress=progress)
    if args.dump_syms:
      libs.DumpSymbols()
    else:
      sym_profile = {"format": "profileJSONWithSymbolicationTable,1",
                     "profileJSON": profile,
                     "symbolicationTable": libs.SymbolicationTable()}
      if args.output:
        sym_filename = args.output
      else:
        sym_filename = args.filename + ".syms"
      if progress:
        print "Writing symbolicated results to", sym_filename, "..."
      json.dump(sym_profile, open(sym_filename, "wb"))
      if progress:
        print "Done"

if __name__ == "__main__":
  main()
