{ pkgs, npmToken, src }:

let
    # Read the package-lock.json as a Nix attrset
    packageLock = builtins.fromJSON (builtins.readFile (src + "/package-lock.json"));

    # Create an array of all (meaningful) dependencies
    deps =  builtins.attrValues (removeAttrs packageLock.packages [ "" ])
         ++ (if packageLock ? "dependencies"
            then builtins.attrValues (removeAttrs packageLock.dependencies [ "" ])
            else [])
    ;

    # Turn each dependency into a fetchurl call
    tarballs = map (p: pkgs.fetchurl {
        url = p.resolved;
        hash = p.integrity;
        curlOpts = "-H @${pkgs.writeText "authorization.txt" "Authorization: Bearer ${npmToken}"}";
    }) deps;

    # Write a file with the list of tarballs
    tarballsFile = pkgs.writeTextFile {
        name = "tarballs";
        text = builtins.concatStringsSep "\n" tarballs;
    };
in pkgs.stdenv.mkDerivation {
    inherit (packageLock) name version;
    inherit src;
    buildInputs = with pkgs; [ nodejs nodePackages.typescript ];
    buildPhase = ''
        export HOME=$PWD/.home
        export npm_config_cache=$PWD/.npm
        mkdir -p $out
        cd $out/
        cp -r $src/. .

        i=0
        while read p1; read p2; read p3; read p4; read p5; read p6; read p7; read p8;
        do
            i=$((i+8))
            echo "caching $p1 $p2 $p3 $p4 $p5 $p6 $p7 $p8"
            npm cache add "$p1" &
            npm cache add "$p2" &
            npm cache add "$p3" &
            npm cache add "$p4" &
            npm cache add "$p5" &
            npm cache add "$p6" &
            npm cache add "$p7" &
            npm cache add "$p8" &
            wait
        done <${tarballsFile}

        j=0
        while read p;
        do
            j=$((j+1))
            if [ $j -le $i ]
            then
                continue
            fi
            echo "caching $p"
            npm cache add "$p"
        done <${tarballsFile}

        npm ci
        tsc --build .
    '';
}
