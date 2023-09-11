{
  description = "A flake containing npm-builder a function to build npm packages with private registries";

  outputs = { self }: {
    npm-builder = import ./npm-builder.nix;
  };
}
