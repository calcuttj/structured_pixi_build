# Introduction
This is used to exercise/demonstrate how one would use pixi-build to build up DUNE software (starting from the art suite). It includes several pixi workspaces which sequentially build off each other: art + wct --> larsoft --> dune

Each workspace directory already has a pixi.toml file in it (meaning pixi recognizes it as a workspace). 

A pixi workspace can build or consume previously-created conda packages to craft a target environment. Some software dependencies are fetched from conda-forge, and others, depending on the workspace, 
are fetched from a previously-built workspace (i.e. larsoft uses some conda packages from the art and wct workspaces). The sources are specified in a workspace's "channels" item.
They currently have upstream channels hardcoded to a path on a specific BNL server. For different machines, one should change these to locations to their own machine. I will explain further later, but will
first give instructions for building the art workspace.

# Usage

## Building art
Navigate to art_workspace and simply run `pixi install`. It will pull down any dependencies from conda-forge and will build the target recipes specified under the `[dependencies]` block of art_workspace/pixi.toml

## Creating a channel
I have not found a native way to stage the built conda packages from a pixi-build run into a channel, so there's a script `harvest-conda-source.py` that reads the `pixi.lock` file to identify
newly built packages and to stage them into a target channel. 

<pre>
  ./harvest-conda-source.py -o art-channel art_workspace/pixi.lock 
</pre>

This will take the newly-built conda packages and move them to art-channel. You then have to `index` them to make pixi recognize it as a local channel hosting conda packages. Run the following command 

<pre>
  pixi exec 
</pre>

## Building wct
wire-cell-toolkit is the only thing in wct-workspace, it doesn't require `art` dependencies, so you can just run `pixi install` to install it, then make a channel (move conda packages + index) as before.

## Building larsoft
