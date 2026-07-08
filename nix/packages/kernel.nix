{ mkKernel, target }:

mkKernel {
  name = "boson-${target.name or "unknown"}-kernel";
  inherit target;
}
