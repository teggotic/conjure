-- [nfnl] Compiled from fnl/conjure/client/haskell/stdio.fnl by https://github.com/Olical/nfnl, do not edit.
local _local_1_ = require("nfnl.module")
local autoload = _local_1_["autoload"]
local a = autoload("conjure.aniseed.core")
local extract = autoload("conjure.extract")
local str = autoload("conjure.aniseed.string")
local stdio = autoload("conjure.remote.stdio")
local config = autoload("conjure.config")
local text = autoload("conjure.text")
local mapping = autoload("conjure.mapping")
local client = autoload("conjure.client")
local log = autoload("conjure.log")
local ts = autoload("conjure.tree-sitter")
local text0 = autoload("conjure.text")
local b64 = autoload("conjure.remote.transport.base64")
config.merge({client = {haskell = {stdio = {command = "stack repl", ["prompt-pattern"] = "ghci> "}}}})
if config["get-in"]({"mapping", "enable_defaults"}) then
  config.merge({client = {haskell = {stdio = {mapping = {start = "cs", stop = "cS", interrupt = "ei"}}}}})
else
end
local cfg = config["get-in-fn"]({"client", "haskell", "stdio"})
local state
local function _3_()
  return {repl = nil}
end
state = client["new-state"](_3_)
local buf_suffix = ".hs"
local comment_prefix = "-- "
local function prep_code(s)
  local s0 = text0["trim-last-newline"](s)
  if a["nil?"](string.find(s0, "\n")) then
    return (s0 .. "\n")
  else
    local s1 = (":{\n" .. s0 .. "\n:}\n")
    print("prep-code")
    print(vim.inspect(s1))
    return s1
  end
end
local function with_repl_or_warn(f, opts)
  local repl = state("repl")
  if repl then
    return f(repl)
  else
    return log.append({(comment_prefix .. "No REPL running"), (comment_prefix .. "Start REPL with " .. config["get-in"]({"mapping", "prefix"}) .. cfg({"mapping", "start"}))})
  end
end
local function format_msg(msg)
  local function _6_(_241)
    return ("" ~= _241)
  end
  return a.filter(_6_, text0["split-lines"](msg))
end
local function unbatch(msgs)
  local function _7_(_241)
    return (a.get(_241, "out") or a.get(_241, "err"))
  end
  return str.join("", a.map(_7_, msgs))
end
local function get_console_output_msgs(msgs)
  local function _8_(_241)
    return (comment_prefix .. "(out) " .. _241)
  end
  return a.map(_8_, a.butlast(msgs))
end
local function get_expression_result(msgs)
  local result = a.last(msgs)
  if a["nil?"](result) then
    return nil
  else
    return result
  end
end
local function log_repl_output(msgs)
  local msgs0 = format_msg(unbatch(msgs))
  local console_output_msgs = get_console_output_msgs(msgs0)
  local cmd_result = get_expression_result(msgs0)
  if not a["empty?"](console_output_msgs) then
    log.append(console_output_msgs)
  else
  end
  if cmd_result then
    return log.append({cmd_result})
  else
    return nil
  end
end
local function eval_str(opts)
  local function _12_(repl)
    local function _13_(msgs)
      log_repl_output(msgs)
      if opts["on-result"] then
        local msgs0 = format_msg(unbatch(msgs))
        local cmd_result = get_expression_result(msgs0)
        return opts["on-result"](cmd_result)
      else
        return nil
      end
    end
    return repl.send(prep_code(opts.code), _13_, {["batch?"] = true})
  end
  return with_repl_or_warn(_12_)
end
local function eval_file(opts)
  return eval_str(a.assoc(opts, "code", a.slurp(opts["file-path"])))
end
local function display_repl_status(status)
  return log.append({(comment_prefix .. cfg({"command"}) .. " (" .. (status or "no status") .. ")")}, {["break?"] = true})
end
local function stop()
  local repl = state("repl")
  if repl then
    repl.destroy()
    display_repl_status("stopped")
    return a.assoc(state(), "repl", nil)
  else
    return nil
  end
end
local function start()
  log.append({(comment_prefix .. "Starting Haskell client...")})
  if state("repl") then
    return log.append({(comment_prefix .. "Can't start, REPL is already running."), (comment_prefix .. "Stop the REPL with " .. config["get-in"]({"mapping", "prefix"}) .. cfg({"mapping", "stop"}))}, {["break?"] = true})
  else
    local function _16_()
      if vim.treesitter.language.require_language then
        return vim.treesitter.language.require_language("haskell")
      else
        return vim.treesitter.require_language("haskell")
      end
    end
    if not pcall(_16_) then
      return log.append({(comment_prefix .. "(error) The Haskell client requires a haskell treesitter parser in order to function."), (comment_prefix .. "(error) See https://github.com/nvim-treesitter/nvim-treesitter"), (comment_prefix .. "(error) for installation instructions.")})
    else
      local function _18_()
        return display_repl_status("started")
      end
      local function _19_(err)
        return display_repl_status(err)
      end
      local function _20_(code, signal)
        if (("number" == type(code)) and (code > 0)) then
          log.append({(comment_prefix .. "process exited with code " .. code)})
        else
        end
        if (("number" == type(signal)) and (signal > 0)) then
          log.append({(comment_prefix .. "process exited with signal " .. signal)})
        else
        end
        return stop()
      end
      local function _23_(msg)
        return log.dbg(format_msg(unbatch({msg})), {["join-first?"] = true})
      end
      return a.assoc(state(), "repl", stdio.start({["prompt-pattern"] = cfg({"prompt-pattern"}), cmd = cfg({"command"}), ["delay-stderr-ms"] = cfg({"delay-stderr-ms"}), ["on-success"] = _18_, ["on-error"] = _19_, ["on-exit"] = _20_, ["on-stray-output"] = _23_}))
    end
  end
end
local function on_exit()
  return stop()
end
local function interrupt()
  local function _26_(repl)
    log.append({(comment_prefix .. " Sending interrupt signal.")}, {["break?"] = true})
    return repl["send-signal"](vim.loop.constants.SIGINT)
  end
  return with_repl_or_warn(_26_)
end
local function on_load()
  if config["get-in"]({"client_on_load"}) then
    return start()
  else
    return nil
  end
end
local function on_filetype()
  mapping.buf("HaskellStart", cfg({"mapping", "start"}), start, {desc = "Start the Haskell REPL"})
  mapping.buf("HaskellStop", cfg({"mapping", "stop"}), stop, {desc = "Stop the Haskell REPL"})
  return mapping.buf("HaskellInterrupt", cfg({"mapping", "interrupt"}), interrupt, {desc = "Interrupt the current evaluation"})
end
return {["buf-suffix"] = buf_suffix, ["comment-prefix"] = comment_prefix, ["format-msg"] = format_msg, unbatch = unbatch, ["eval-str"] = eval_str, ["eval-file"] = eval_file, stop = stop, start = start, ["on-load"] = on_load, ["on-exit"] = on_exit, interrupt = interrupt, ["on-filetype"] = on_filetype}
