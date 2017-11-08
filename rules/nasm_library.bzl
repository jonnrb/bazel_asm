def _cc_nasm(ctx, opts, src):
  nasm_bin = ctx.attr.nasm_bin
  out = ctx.actions.declare_file(src.basename.replace(src.extension, "o"))
  opts = opts + [src.path, "-o", out.path]
  inputs = []

  for i in ctx.attr.srcs + ctx.attr.hdrs + ctx.attr.deps:
    if hasattr(i, "files"):
      inputs += i.files.to_list()
    else:
      inputs.append(i)

  #print("nasm",*opts)

  ctx.actions.run(
      outputs = [out],
      inputs = inputs,
      arguments = opts,
      executable = nasm_bin,
      mnemonic = "NasmCompile")

  return out


def _is_nasm_src(f):
  return f.extension == "asm" or f.extension == "nasm"


def _maybe_add(src, include_paths):
  if not _is_nasm_src(src):
    return
  root_path = ("./" + src.root_path + "/") if src.root.path else "."
  dirname = ("./" + src.dirname + "/") if src.dirname else "."
  if root_path not in include_paths:
    include_paths.append(root_path)
  if dirname not in include_paths:
    include_paths.append(dirname)


def _include_paths(ctx):
  include_paths = []
  for i in (ctx.attr.srcs + ctx.attr.hdrs + ctx.attr.deps):
    # check if `i` is a target
    if hasattr(i, "files"):
      for src in i.files:
        _maybe_add(src, include_paths)
    else:
      _maybe_add(i.root, include_paths)

  return ["-I{}".format(r) for r in include_paths]


def _nasm_library_impl(ctx):
  opts = ctx.attr.copts + _include_paths(ctx)
  deps = [_cc_nasm(ctx, opts, src) for target in ctx.attr.srcs
          for src in target.files.to_list()]
  for i in ctx.attr.hdrs:
    if hasattr(i, "files"):
      deps += i.files.to_list()
    else:
      deps.append(i)
  return DefaultInfo(files=depset(deps))


_nasm_library = rule(
  implementation=_nasm_library_impl,
  attrs={
    "srcs": attr.label_list(allow_files=True),
    "hdrs": attr.label_list(allow_files=True),
    "deps": attr.label_list(allow_files=True),
    "copts": attr.string_list(),
    "nasm_bin": attr.string(),
  })


# on macOS, the nasm in /usr/bin is horrifically old (and i believe forked?)
NASM_BIN_DEFAULT = select({
    ":macos": "/usr/local/bin/nasm",
    ":linux": "/usr/bin/nasm",
})


NASM_ARCH_OPTS = select({
    ":macos": ["-f", "macho64"],
    ":linux": ["-f", "elf64"],
})


def nasm_library(name, srcs, hdrs=[], deps=[], copts=[],
                 nasm_bin=NASM_BIN_DEFAULT):
  _nasm_library(
      name = name,
      srcs = srcs,
      hdrs = hdrs,
      deps = deps,
      copts = NASM_ARCH_OPTS + copts,
      nasm_bin = nasm_bin
  )
