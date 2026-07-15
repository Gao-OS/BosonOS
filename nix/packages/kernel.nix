{
  mkKernel,
  target,
  linuxPackages,
}:

mkKernel {
  name = "boson-${target.name or "unknown"}-kernel";
  inherit target;
  kernelPackage = linuxPackages.kernel;
}
