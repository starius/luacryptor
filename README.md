luacryptor
==========

Convert Lua file to C file with all functions encrypted

To get list of commands, run `luacryptor.lua`
without arguments.

Luacryptor creates .c file, which can be compiled into
binary library. Loading this library into Lua works as if
original Lua module was loaded.

Loading requires password. Set password in Lua registry.

Lua:

```lua
    debug.getregistry().__luacryptor_pwd = "password"
```

C:

```c
    lua_pushstring(L, "password");
    lua_setfield(L, LUA_REGISTRYINDEX, "__luacryptor_pwd");
```

Command `embed` encrypts whole Lua file. No restrictions
on source Lua file.

Command `encfunc` encrypts individual functions in Lua module.
Lua module must return table, all elements of which are
functions. Functions may have up to one upvalue, module
itself. Source of luacryptor.lua can serve as example.

Option `--bytecode` tells luacryptor to compile Lua sources
to bytecode before encrypting. Target and Host Lua version
must have compatible bytecode versions.

## Encryption

Twofish with 256 bit key in CTR mode.
CTR mode is implemented as follows:

  * 16 bytes (nonce) are read from /dev/urandom and written
     in the beginning of cryptotext.
  * int counter = 0
  * For each block:
    * Calculate XOR(nonce, counter). Counter is aligned to
      the end of block in Big-endian mode.
    * Twofish(block)
    * XOR result with input
    * Increment counter

No padding required. CTR works like stream mode.

Password is hashed with SHA-256.
Function names are replaced with `sha256(password .. name)`.

File and function bodies are encrypted with twofish with
`key=sha256(password .. name)`.

