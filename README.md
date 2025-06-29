# ZIGonut

[![See it in action!](https://asciinema.org/a/uJKT3Pfftig002yJAXeGYM8Jo.svg)](https://asciinema.org/a/uJKT3Pfftig002yJAXeGYM8Jo)

Is it the everything bagel? Homer Simpson's dream? A point cloud generated from
the equation of a torus and rasterized to an ascii representation?

Who Knows! I means, it's definitely the last one, but still...let your
imagination run wild. It helps when there's only bad graphics available.

## But what is it?

Zignout creates a point cloud representing a torus using the equations:

- $x(\theta, \phi) = (R+r \sin \theta) \cos \phi$
- $y(\theta, \phi) = (R+r \sin \theta) \sin \phi$
- $z(\theta, \phi) = r \cos \theta$

This point cloud is then rotated about each axis ($x$,$y$, and $z$) using a two
dimensional rotation matrix, e.g.

```math
\begin{bmatrix} \cos \theta & - \sin \theta \\ \sin \theta & \cos \theta \end{bmatrix}
```

The torus is then rasterized by steping through each point in the cloud, and
finding the nearest z-coordinate in each patch that will be represented by a
single character. These z-coordinates are then translated into characters which
were chosen so that they are brighter the closer the points of the torus are to
the screen.

This is not an efficient way to do the rendering, and it requires a lot of
points to look decent (you can play around with the 'step' parameters to see how
it looks with different numbers of points), but it was a fun experiment.

## How can I use this amazing piece of software?

You can clone this repository, and then build it using zig (you'll need at least
version 0.15.0). Also, it has only been tested on linux...though it should work
anywhere that is relatively posix compliant, best of luck on that.
