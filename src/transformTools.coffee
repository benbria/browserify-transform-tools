# Framework for building Falafel based transforms for Browserify.

# Based loosely on https://github.com/quarterto/rfolderify

path    = require 'path'
fs      = require 'fs'

through   = require 'through'
falafel   = require 'falafel'

endsWith = (str, suffix) ->
    return str.indexOf(suffix, str.length - suffix.length) != -1

# Find the first parent directory of `startDir` which contains a file named `fileToFind`.
parentDirSync = (startDir, fileToFind) ->
    existsSync = fs.existsSync ? path.existsSync

    dirToCheck = path.resolve startDir

    answer = null
    while true
        if existsSync path.join(dirToCheck, fileToFind)
            answer = dirToCheck
            break

        oldDirToCheck = dirToCheck
        dirToCheck = path.dirname dirToCheck
        if oldDirToCheck == dirToCheck
            # We've hit '/'.  We're done
            break

    return answer

# Create a new Browserify transform which reads and returns a string.
#
# Browserify transforms work on streams.  This is all well and good, until you want to call
# a library like "falafel" which doesn't work with streams.
#
# Suppose you are writing a transform called "redify" which replaces all occurances of "blue"
# with "red":
#
#     options = {}
#     module.exports = makeStringTransform "redify", options, (contents) ->
#         return contents.replace(/blue/g, "red")
#
# Parameters:
# * `transformFn(contents, {file, config})` - Function which is called to do the transform.
#   `contents` are the contents of the file.  `file` is the name of the file (as would be
#   passed to a normal browserify transform.)  `config` is the configuration for the
#   `redify` transform (see `loadTransformConfigSync` below for details on where this comes from.)
# * `options.excludeExtensions` - A list of extensions which will not be processed.  e.g.
#   "['.coffee', '.jade']"
# * `options.includeExtensions` - A list of extensions to process.  If this options is not
#   specified, then all extensions will be processed.  If this option is specified, then
#   any file with an extension not in this list will skipped.
#
exports.makeStringTransform = (transformName, options={}, transformFn) ->
    if !transformFn?
        transformFn = options
        options = {}

    (file) ->
        if options.excludeExtensions
            for extension in options.excludeExtensions
                if endsWith(file, extension) then return through()

        if options.includeExtensions
            includeThisFile = false
            for extension in options.includeExtensions
                if endsWith(file, extension)
                    includeThisFile = true
                    break
            if !includeThisFile then return through()

        data = ''

        # Read the file contents into `data`
        write = (buf) -> data += buf

        # Called when we're done reading dfile contents
        end = ->
            try
                config = exports.loadTransformConfigSync transformName, file
                output = transformFn data, {file, config}
            catch err
                @emit 'error', new Error(
                    err.toString() + " (#{file})")

            @queue String(output)
            @queue null

        return through write, end

# Create a new Browserify transform based on [falafel](https://github.com/substack/node-falafel).
#
# The resulting transform will call `transformFn(node {file, config})` for every falafel node.
# The return value of transformFn is ignored.
#
# `transformName`, `options`, `file`, and `config` are the same as for `makeStringTransform()`.
#
exports.makeFalafelTransform = (transformName, options={}, transformFn) ->
    if !transformFn?
        transformFn = options
        options = {}

    return exports.makeStringTransform transformName, options, (content, transformOptions) ->
        return falafel content, (node) ->
            transformFn node, transformOptions

# Create a new Browserify transform that modifies requires() calls.
#
# The resulting transform will call `transformFn(requireArgs, {file, config})` for every requires
# in a file.  transformFn should return a string which will replace the entire `require` call.
#
# Exmaple:
#
#     makeRequireTransform "xify", (requireArgs) ->
#         return "require(x" + requireArgs[0] + ")"
#
# would transform calls like `require("foo")` into `require("xfoo")`.
#
# `transformName`, `options`, `file`, and `config` are the same as for `makeStringTransform()`.
#
# exports.makeRequireTransform = (transformName, options={}, transformFn) ->
#     return makeFalafelTransform transformName, options, (node, transformOptions) ->
#         if (node.type is 'CallExpression' and
#         node.callee.type is 'Identifier' and
#         node.callee.name is 'require')
#                 # Parse arguemnts to calls to `require`.
#                 args = (arg.source() for arg in node.arguments)
#                 node.update transformFn(args, transformOptions)


readConfigFromPacakge = (transformName, packageDir) ->
    answer = null

    if packageDir?
        packageFile = path.join(packageDir, 'package.json');
        pkg = require packageFile
        answer = pkg[transformName]

        if answer? and (typeof answer is "string")
            configFile = path.resolve packageDir, answer
            answer = require configFile

    return answer

configCache = {}

# Load configuration for a transform.
#
# This will look for a key in package.json with configuration for your module.  Suppose you
# write a transform called "soupify".  In your transform, you'd do something like:
#
#     config = browserifyTransformTools.loadTransformConfigSync "soupify",
#         "/Users/jwalton/project/foo.js"
#
# This will find the "soupify" key in package.json.  If the value of the key is an object,
# this will return that object.  If the value of the key is a string, this will load the
# JSON or js file referenced by the string, and return its contents instead.
#
# Note that `loadTransformConfigSync` will cache the configuration for the transfromName, so it
# doesn't need to be looked up for each individual file.
#
# Inspired by the [browserify-shim](https://github.com/thlorenz/browserify-shim) configuration
# loader.
#
exports.loadTransformConfigSync = (transformName, file) ->
    answer = null

    if transformName of configCache
        answer = configCache[transformName]
    else
        dirname = path.dirname file
        packageDir = parentDirSync dirname, 'package.json'
        answer = readConfigFromPacakge transformName, packageDir
        configCache[transformName] = answer

    return answer

# Runs a Browserify-style transform on the given file.
#
# * `transform` is the transform to run (i.e. a `fn(file)` which returns a through stream.)
# * `file` is the name of the file to run the transform on.
# * `options.content` is the content of the file.  If this option is not provided, the content
#   will be read from disk.
# * `done(err, result)` will be called with the transformed input.
#
exports.runTransform = (transform, file, options={}, done) ->
    if !done?
        done = options
        options = {}

    doTransform = (content) ->
        data = ""
        err = null

        throughStream = transform(file)
        throughStream.on "data", (d) ->
            data += d
        throughStream.on "end", ->
            done err, data
        throughStream.on "error", (e) ->
            err = e

        throughStream.write content
        throughStream.end()

    if options.content
        process.nextTick -> doTransform options.content
    else
        fs.readFile file, "utf-8", (err, content) ->
            return done err if err
            doTransform content
