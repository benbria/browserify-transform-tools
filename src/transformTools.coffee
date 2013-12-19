# Framework for building Falafel based transforms for Browserify.

path    = require 'path'
fs      = require 'fs'

through   = require 'through'
falafel   = require 'falafel'
parentDir = require 'find-parent-dir'

endsWith = (str, suffix) ->
    return str.indexOf(suffix, str.length - suffix.length) != -1

# Returned true if the given file should not be procesed, given the specified options.
skipFile = (file, options) ->
    answer = false

    if options.excludeExtensions
        for extension in options.excludeExtensions
            if endsWith(file, extension) then answer = true

    if options.includeExtensions
        includeThisFile = false
        for extension in options.includeExtensions
            if endsWith(file, extension)
                includeThisFile = true
                break
        if !includeThisFile then answer = true

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
#     module.exports = makeStringTransform "redify", options, (contents, transformOptions, done) ->
#         done null, contents.replace(/blue/g, "red")
#
# Parameters:
# * `transformFn(contents, transformOptions, done)` - Function which is called to
#   do the transform.  `contents` are the contents of the file.  `transformOptions.file` is the
#   name of the file (as would be passed to a normal browserify transform.)
#   `transformOptions.config` is the configuration for the transform (see
#   `loadTransformConfig` below for details on where this comes from.)  `done(err, transformed)` is
#   a callback which must be called, passing the a string with the transformed contents of the
#   file.
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
        if skipFile file, options then return through()

        # Read the file contents into `content`
        content = ''
        write = (buf) -> content += buf

        # Called when we're done reading file contents
        end = ->
            handleError = (error) =>
                if error instanceof Error and error.message
                    error.message += " (while processing #{file})"
                else
                    error = new Error("#{error} (while processing #{file})")
                @emit 'error', error

            exports.loadTransformConfig transformName, file, (err, config) =>
                return handleError err if err

                try
                    transformFn content, {file, config}, (err, transformed) =>
                        return handleError err if err
                        @queue String(transformed)
                        @queue null
                catch err
                    handleError err

        return through write, end

# Create a new Browserify transform based on [falafel](https://github.com/substack/node-falafel).
#
# Parameters:
# * `transformFn(node, transformOptions, done)` is called once for each falafel node.  transformFn
#   is free to update the falafel node directly; any value returned via `done(err)` is ignored.
# * `options.falafelOptions` are options to pass directly to Falafel.
# * `transformName`, `options.excludeExtensions`, `options.includeExtensions`, and `transformOptions`
#   are the same as for `makeStringTransform()`.
#
exports.makeFalafelTransform = (transformName, options={}, transformFn) ->
    if !transformFn?
        transformFn = options
        options = {}

    falafelOptions = options.falafelOptions ? {}

    return exports.makeStringTransform transformName, options, (content, transformOptions, done) ->
        transformErr = null
        pending = 1 # We'll decrement this to zero at the end to prevent premature call of `done`.
        transformed = null

        transformCb = (err) ->
            if err and !transformErr
                transformErr = err
                done err

            # Stop further processing if an error has occurred
            return if transformErr

            pending--
            if pending is 0
                done null, transformed

        transformed = falafel content, falafelOptions, (node) ->
            pending++
            try
                transformFn node, transformOptions, transformCb
            catch err
                transformCb err

        # call transformCb one more time to decrement pending to 0.
        transformCb transformErr, transformed

# Create a new Browserify transform that modifies requires() calls.
#
# The resulting transform will call `transformFn(requireArgs, tranformOptions, cb)` for every
# requires in a file.  transformFn should call `cb(null, str)` with a string which will replace the
# entire `require` call.
#
# Exmaple:
#
#     makeRequireTransform "xify", (requireArgs, cb) ->
#         cb null, "require(x" + requireArgs[0] + ")"
#
# would transform calls like `require("foo")` into `require("xfoo")`.
#
# `transformName`, `options.excludeExtensions`, `options.includeExtensions`, and
# `tranformOptions` are the same as for `makeStringTransform()`.
#
# By default, makeRequireTransform will attempt to evaluate each "require" parameters.
# makeRequireTransform can handle variabls `__filename`, `__dirname`, `path`, and `join` (where
# `join` is treated as `path.join`) as well as any basic JS expressions.  If the argument is
# too complicated to parse, then makeRequireTransform will return the source for the argument.
# You can disable parsing by passing `options.evaluateArguments` as false.
#
exports.makeRequireTransform = (transformName, options={}, transformFn) ->
    if !transformFn?
        transformFn = options
        options = {}

    evaluateArguments = options.evaluateArguments ? true

    return exports.makeFalafelTransform transformName, options, (node, transformOptions, done) ->
        if (node.type is 'CallExpression' and node.callee.type is 'Identifier' and
        node.callee.name is 'require')
            # Parse arguemnts to calls to `require`.
            if evaluateArguments
                # Based on https://github.com/ForbesLindesay/rfileify.
                dirname = path.dirname(transformOptions.file)
                varNames = ['__filename', '__dirname', 'path', 'join']
                vars = [transformOptions.file, dirname, path, path.join]

                args = node.arguments.map (arg) ->
                    t = "return #{arg.source()}"
                    try
                        return Function(varNames, t).apply(null, vars)
                    catch err
                        # Can't evaluate the arguemnts.  Return the raw source.
                        return arg.source()
            else
                args = (arg.source() for arg in node.arguments)

            transformFn args, transformOptions, (err, transformed) ->
                return done err if err
                if transformed? then node.update(transformed)
                done()
        else
            done()

# Cache for transform configuration.
configCache = {}

getConfigFromCache = (transformName, packageDir) ->
    cacheKey = "#{transformName}:#{packageDir}"
    return if configCache[cacheKey]? then configCache[cacheKey] else null

storeConfigInCache = (transformName, packageDir, config) ->
    cacheKey = "#{transformName}:#{packageDir}"
    configCache[cacheKey] = config

loadJsonAsync = (filename, done) ->
    fs.readFile filename, "utf-8", (err, content) ->
        return done err if err
        try
            done null, JSON.parse(content)
        catch err
            done err

# Load configuration for a transform.
#
# This will look for a key in package.json with configuration for your module.  Suppose you
# write a transform called "soupify".  In your transform, you'd do something like:
#
#     browserifyTransformTools.loadTransformConfig "soupify",
#         "/Users/jwalton/project/foo.js", (err, config) ->
#             ....
#
# This will find the "soupify" key in package.json.  If the value of the key is an object,
# this will return that object.  If the value of the key is a string, this will load the
# JSON or js file referenced by the string, and return its contents instead.
#
# Inspired by the [browserify-shim](https://github.com/thlorenz/browserify-shim) configuration
# loader.
#
exports.loadTransformConfig = (transformName, file, done) ->
    dirname = path.dirname file
    parentDir dirname, 'package.json', (err, packageDir) ->
        return done err if err

        config = getConfigFromCache transformName, packageDir
        if config
            done null, config

        else if packageDir?
            packageFile = path.join(packageDir, 'package.json');
            loadJsonAsync packageFile, (err, pkg) ->
                return done err if err
                config = pkg[transformName]

                if config? and (typeof config is "string")
                    configFile = path.resolve packageDir, config
                    try
                        config = require configFile
                    catch err
                        return done err

                storeConfigInCache transformName, packageDir, config
                done null, config

        else
            # Couldn't find configuration
            done null, null


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

# Synchronous version of `loadTransformConfig()`.
exports.loadTransformConfigSync = (transformName, file) ->
    config = null

    dirname = path.dirname file
    packageDir = parentDirSync dirname, 'package.json'

    config = getConfigFromCache transformName, packageDir

    if !config and packageDir?
        packageFile = path.join(packageDir, 'package.json');
        pkg = require packageFile
        config = pkg[transformName]

        if config? and (typeof config is "string")
            configFile = path.resolve packageDir, config
            config = require configFile

        storeConfigInCache transformName, packageDir, config

    return config

exports.clearConfigCache = ->
    configCache = {}

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
            if !err then done null, data
        throughStream.on "error", (e) ->
            err = e
            done err

        throughStream.write content
        throughStream.end()

    if options.content
        process.nextTick -> doTransform options.content
    else
        fs.readFile file, "utf-8", (err, content) ->
            return done err if err
            doTransform content
