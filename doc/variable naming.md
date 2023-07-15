| variable name | meaning              | code                               |
|---------------|----------------------|------------------------------------|
| pos           | position             | `vector.new(x, y, z)`              |
| poss          | table of positions   | `{ pos }`                          |
| spos          | position as a string | `minetest.pos_to_string(pos)`      |
| hpos          | hashed position      | `minetest.hash_node_position(pos)` |
| hposs         | table of hpos        | `{ hpos }`                         |
