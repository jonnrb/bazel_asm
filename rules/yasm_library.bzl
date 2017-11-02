def _cc_yasm(ctx, opts, src):
  yasm_bin = ctx.attr.yasm_bin
  out = ctx.actions.declare_file(src.basename.replace(src.extension, "o"))
  opts = opts + [src.path, '-o', out.path]
  inputs = []

  for i in ctx.attr.srcs + ctx.attr.hdrs + ctx.attr.deps:
    if hasattr(i, "files"):
      inputs += i.files.to_list()
    else:
      inputs.append(i)

  ctx.actions.run(
      outputs = [out],
      inputs = inputs,
      arguments = opts,
      executable = yasm_bin,
      mnemonic = 'YasmCompile',
  )

  return out


def _is_yasm_src(f):
  return f.extension == "asm" or f.extension == "yasm"


def _root_path_maybe_add(ctx, src, root_paths):
  if not _is_yasm_src(src):
    return
  if src.root.path:
    root_path = src.root.path
    if ctx.label.workspace_root:
      root_path += "/" + ctx.label.workspace_root
    if root_path and root_path not in root_paths:
      root_paths.append(root_path + ("/" + ctx.attr.strip_include_prefix
                                     if ctx.attr.strip_include_prefix else ""))
  if ctx.label.workspace_root and ctx.attr.strip_include_prefix:
    root_path = ctx.label.workspace_root + "/" + ctx.attr.strip_include_prefix
    if src.path.startswith(root_path) and root_path not in root_paths:
      root_paths.append(root_path)


def _include_paths(ctx):
  root_paths = ["."]
  if ctx.attr.strip_include_prefix:
    if ctx.label.workspace_root:
      root_paths.append(ctx.label.workspace_root + "/" +
                        ctx.attr.strip_include_prefix)
    else:
      root_paths.append(ctx.attr.strip_include_prefix)

  for i in (ctx.attr.srcs + ctx.attr.hdrs + ctx.attr.deps):
    # check if `i` is a target
    if hasattr(i, "files"):
      for src in i.files:
        _root_path_maybe_add(ctx, src, root_paths)
    else:
      _root_path_maybe_add(ctx, i.root, root_paths)

  return ["-I{}".format(r) for r in root_paths]


def _preincludes_maybe_add(ctx, src, preincludes):
  if not _is_yasm_src(src):
    return
  if src.path not in preincludes:
    # if ctx.attr.strip_include_prefix and \
    #     src.short_path.split(ctx.attr.strip_include_prefix)[0]:
    #   fail("source '{}' does not start with strip_include_prefix '{}'".format(
    #       src.short_path, ctx.attr.strip_include_prefix))
    preincludes.append(src.path)


def _preincludes(ctx):
  preincludes = []
  for i in (ctx.attr.preincludes):
    # check if `i` is a target
    if hasattr(i, "files"):
      for src in i.files:
        _preincludes_maybe_add(ctx, src, preincludes)
    else:
      _preincludes_maybe_add(ctx, i, preincludes)

  return ["-P{}".format(p) for p in preincludes]


def _yasm_library_impl(ctx):
  opts = ctx.attr.copts + _include_paths(ctx) + _preincludes(ctx)
  deps = [_cc_yasm(ctx, opts, src) for target in ctx.attr.srcs
          for src in target.files.to_list()]
  for i in ctx.attr.hdrs:
    if hasattr(i, "files"):
      deps += i.files.to_list()
    else:
      deps.append(i)
  return DefaultInfo(files=depset(deps))


yasm_library = rule(
  implementation=_yasm_library_impl,
  attrs={
    "yasm_bin": attr.string(default="/usr/local/bin/yasm"),
    "preincludes": attr.label_list(allow_files=True),
    "strip_include_prefix": attr.string(),
    "srcs": attr.label_list(allow_files=True),
    "hdrs": attr.label_list(allow_files=True),
    "deps": attr.label_list(allow_files=True),
    "copts": attr.string_list(),
  })
