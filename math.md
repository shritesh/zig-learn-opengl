# Length of a Vector

- Length of a vector `v` is `sqrt(v.x * v.x + v.y * v.y)`
- Normalized vectors have length 1. Divide the vector by it's length to
  normalize.

# Dot Product

- Dot product of a vector `a` and `b` with `theta` angle between them is
  `length(a) * length(b) * cos(theta)`.
- When `a` and `b` are unit vectors (their length is 1), the dot product gives
  `cos(theta)`.
- `cos(90) = 0` and `cos(0) = 1`. Use a dot product of normalized vectors to
  check if vectors are orthogonal (90 degrees) or parallel (0 degrees)
- `dot(a, b) = (a.x * b.x) + (a.y * b.y) + (a.z * b.z)`
- Inverse cosine on `theta = inverse_cosine(dot(a, b))`

# Cross product

- Cross product of vector `a` and `b` produces a vector `c` that is orthogonal
  to both `a` and `b`.
- Only defined in 3D space and for non-parallel vectors.
- For orthogonal vectors `a` and `b` the cross product
  `c = (a.y * b.z - a.z - b.y), (a.z * b.x - a.x * b.z), (a.x * b.y - a.y * b.x)`

# Matrix

- Named based on number of `rows x columns`: `2x3` matrix has 2 rows, 3 columns
- Indexed by `(i, j)` where `i` is the row and `j` is the column

# Matrix-Matrix Multiplication

- Only defined when number of columns on the left side is the same as number of
  columns on the right side.
- Not commutitve `A * B != B * A`

```
| 1 2 | (X) | 5 6 | (=) | (1*5 + 2*7) (1*6 + 2*8) |
| 3 4 |     | 7 8 |     | (3*5 + 4*7) (3*6 + 4*8) |
```

# Matrix-Vector Multiplication

- A vector is Nx1 Matrix, where n is the number of components
- Multiplying some matrices by a vector, transforms the vector
- Transformation matrices can themselves be multiplied
- Recommended ordering: scale -> rotate -> translate

## Identity Matrix

- Forms the basis for other transformations

```
| 1 0 0 0 | (X) | x | (=) | x |
| 0 1 0 0 |     | y |     | y |
| 0 0 1 0 |     | z |     | z |
| 0 0 0 1 |     | w |     | w |
```

## Scaling

- Grows or shrinks the vector

```
| a 0 0 0 | (X) | x | (=) | x*a |
| 0 b 0 0 |     | y |     | y*b |
| 0 0 c 0 |     | z |     | z*c |
| 0 0 0 1 |     | 1 |     | 1   |
```

## Translation

- Moves the vector

```
| 1 0 0 a | (X) | x | (=) | x+a |
| 0 1 0 b |     | y |     | y+b |
| 0 0 1 c |     | z |     | z+c |
| 0 0 0 1 |     | 1 |     | 1   |
```

## Rotation

```
Around the X-axis

| 1 0       0      0 | (X) | x | (=) | x                   |
| 0 cos(t) -sin(t) 0 |     | y |     | cos(t)*y - sin(t)*z |
| 0 sin(t)  cos(t) 0 |     | z |     | sin(t)*y - cos(t)*z |
| 0 0       0      1 |     | 1 |     | 1                   |

Around the Y-axis

|  cos(t) 0 sin(t) 0 | (X) | x | (=) |  cos(t)*x + sin(t)*z |
|  0      1 0      0 |     | y |     |  y                   |
| -sin(t) 0 cos(t) 0 |     | z |     | -sin(t)*x + cos(t)*z |
|  0      0 0      1 |     | 1 |     |  1                   |

Around the Z-axis

| cos(t) -sin(t) 0 0 | (X) | x | (=) | cos(t)*x - sin(t)*y |
| sin(t)  cos(t) 0 0 |     | y |     | sin(t)*x + cos(t)*y |
| 0       0      1 0 |     | z |     | z                   |
| 0       0      0 1 |     | 1 |     | 1                   |
```
