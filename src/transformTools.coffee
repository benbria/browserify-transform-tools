# Framework for building Falafel based transforms for Browserify.

path    = require 'path'
fs      = require 'fs'

through   = require 'through'
falafel   = require 'falafel'

parentDir = require './parentDir'

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

# TODO: Does this work on Windows?
isRootDir = (filename) -> filename == path.resolve(filename, '/')

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
#   `transformOptions.configData` is the configuration data for the transform (see
#   `loadTransformConfig` below for details.)  `transformOptions.config` is a copy of
#   `transformOptions.configData.config` for convenience.  `done(err, transformed)` is a callback
#   which must be called, passing the a string with the transformed contents of the file.
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

    transform = (file) ->
        if skipFile file, options then return through()

        # Read the file contents into `content`
        content = ''
        write = (buf) -> content += buf

        # Called when we're done reading file contents
        end = ->
            handleError = (error) =>
                suffix = " (while #{transformName} was processing #{file})"
                if error instanceof Error and error.message
                    error.message += suffix
                else
                    error = new Error("#{error}#{suffix}")
                @emit 'error', error

            doTransform = (configData) =>
                try
                    transformOptions = {
                        file: file,
                        configData, configData,
                        config: configData?.config
                    }
                    transformFn content, transformOptions, (err, transformed) =>
                        return handleError err if err
                        @queue String(transformed)
                        @queue null
                catch err
                    handleError err

            if transform.configData
                process.nextTick -> doTransform transform.configData
            else
                exports.loadTransformConfig transformName, file, (err, configData) =>
                    return handleError err if err
                    doTransform configData


        return through write, end

    # Called to manually pass configuration data to the transform.  Configuration passed in this
    # way will override configuration loaded from package.json.
    #
    # * `config` is the configuration data.
    # * `configOptions.configFile` is the file that configuration data was loaded from.  If this
    #   is specified and `configOptions.configDir` is not specified, then `configOptions.configDir`
    #   will be inferred from the configFile's path.
    # * `configOptions.configDir` is the directory the configuration was loaded from.  This is used
    #   by some transforms to resolve relative paths.
    #
    # Returns a new transform that uses the configuration:
    #
    #     myTransform = require('myTransform').configure(...)
    #
    transform.configure = (config, configOptions = {}) ->
        answer = exports.makeStringTransform transformName, options, transformFn
        answer.setConfig config, configOptions
        return answer

    # Similar to `configure()`, but modifies the transform instance it is called on.  This can
    # be used to set the default configuration for the transform.
    transform.setConfig = (config, configOptions = {}) ->
        configFile = configOptions.configFile or null
        configDir = configOptions.configDir or if configFile then path.dirname configFile else null

        if !config
            @configData = null
        else
            @configData = {
                config: config,
                configFile: configFile,
                configDir: configDir,
                cached: false
            }

        return this


    return transform


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

    transform = exports.makeStringTransform transformName, options, (content, transformOptions, done) ->
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

    # Called to manually pass configuration data to the transform.  Configuration passed in this
    # way will override configuration loaded from package.json.
    #
    # * `config` is the configuration data.
    # * `configOptions.configFile` is the file that configuration data was loaded from.  If this
    #   is specified and `configOptions.configDir` is not specified, then `configOptions.configDir`
    #   will be inferred from the configFile's path.
    # * `configOptions.configDir` is the directory the configuration was loaded from.  This is used
    #   by some transforms to resolve relative paths.
    #
    # Returns a new transform that uses the configuration:
    #
    #     myTransform = require('myTransform').configure(...)
    #
    transform.configure = (config, configOptions = {}) ->
        answer = exports.makeFalafelTransform transformName, options, transformFn
        answer.setConfig config, configOptions
        return answer

    return transform

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

    transform = exports.makeFalafelTransform transformName, options, (node, transformOptions, done) ->
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

    # Called to manually pass configuration data to the transform.  Configuration passed in this
    # way will override configuration loaded from package.json.
    #
    # * `config` is the configuration data.
    # * `configOptions.configFile` is the file that configuration data was loaded from.  If this
    #   is specified and `configOptions.configDir` is not specified, then `configOptions.configDir`
    #   will be inferred from the configFile's path.
    # * `configOptions.configDir` is the directory the configuration was loaded from.  This is used
    #   by some transforms to resolve relative paths.
    #
    # Returns a new transform that uses the configuration:
    #
    #     myTransform = require('myTransform').configure(...)
    #
    transform.configure = (config, configOptions = {}) ->
        answer = exports.makeRequireTransform transformName, options, transformFn
        answer.setConfig config, configOptions
        return answer

    return transform

# This is a cache where keys are directory names, and values are the closest ancestor directory
# that contains a package.json
packageJsonCache = {}

findPackageJson = (dirname, done) ->
    answer = packageJsonCache[dirname]
    if answer
        process.nextTick ->
            done null, answer
    else
        parentDir.parentDir dirname, 'package.json', (err, packageDir) ->
            return done err if err
            if packageDir
                packageFile = path.join(packageDir, 'package.json')
            else
                packageFile = null
            packageJsonCache[dirname] = packageFile
            done null, packageFile

findPackageJsonSync = (dirname) ->
    answer = packageJsonCache[dirname]
    if !answer
        packageDir = parentDir.parentDirSync dirname, 'package.json'
        if packageDir
            packageFile = path.join(packageDir, 'package.json')
        else
            packageFile = null
        packageJsonCache[dirname] = packageFile
        answer = packageFile
    return answer

# Cache for transform configuration.
configCache = {}

getConfigFromCache = (transformName, packageFile) ->
    cacheKey = "#{transformName}:#{packageFile}"
    return if configCache[cacheKey]? then configCache[cacheKey] else null

storeConfigInCache = (transformName, packageFile, configData) ->
    cacheKey = "#{transformName}:#{packageFile}"

    # Copy the config data, so we can set `cached` to true without affecting the object passed in.
    cachedConfigData = {}
    for key, value of configData
        cachedConfigData[key] = value
    cachedConfigData.cached = true

    configCache[cacheKey] = cachedConfigData

loadJsonAsync = (filename, done) ->
    fs.readFile filename, "utf-8", (err, content) ->
        return done err if err
        try
            done null, JSON.parse(content)
        catch err
            done err

# Load external configuration from a js or JSON file.
# * `packageFile` is the package.json file which references the external configuration.
# * `relativeConfigFile` is a file name relative to the package file directory.
loadExternalConfig = (packageFile, relativeConfigFile) ->
    # Load from an external file
    packageDir = path.dirname packageFile
    configFile = path.resolve packageDir, relativeConfigFile
    configDir = path.dirname configFile
    config = require configFile
    return {config, configDir, configFile, packageFile, cached: false}

# Load configuration for a transform.
#
# This will look for a key in package.json with configuration for your module.  Suppose you
# write a transform called "soupify".  In your transform, you'd do something like:
#
#     browserifyTransformTools.loadTransformConfig "soupify",
#         "/Users/jwalton/project/foo.js", (err, configData) ->
#             ....
#
# This starts in "/Users/jwalton/project" and walks up the directory tree looking for a
# package.json file.  Once a package.json file is located, this will check for a "soupify" key
# in package.json.  If one does not exist, it will continue walking up the tree until it finds one
# (the first package.json you find might be in a bower component.)
#
# Once the "soupify" key is found, if the value of the key is an object,
# this will return that object.  If the value of the key is a string, this will load the
# JSON or js file referenced by the string, and return its contents instead.
#
# The object returned has the following properties:
# * `configData.config` - The configuration for the transform.
# * `configData.configDir` - The directory the configuration was loaded from; the directory which
#   contains package.json if that's where the config came from, or the directory which contains
#   the file specified in package.json.  This is handy for resolving relative paths.  Note thate
#   this field may be null if the configuration is overridden via the `configure()` function.
# * `configData.configFile` - The file the configuration was loaded from.  Note thate
#   this field may be null if the configuration is overridden via the `configure()` function.
# * `configData.cached` - Since a transform is run once for each file in a project, configuration
#   data is cached using the location of the package.json file as the key.  If this value is true,
#   it means that data was loaded from the cache.
#
# Inspired by the [browserify-shim](https://github.com/thlorenz/browserify-shim) configuration
# loader.
#
exports.loadTransformConfig = (transformName, file, done) ->
    dir = path.dirname file

    findConfig = (dirname) ->
        findPackageJson dirname, (err, packageFile) ->
            return done err if err

            if !packageFile?
                # Couldn't find configuration
                done null, null
            else
                configData = getConfigFromCache transformName, packageFile
                if configData
                    done null, configData
                else
                    loadJsonAsync packageFile, (err, pkg) ->
                        return done err if err

                        config = pkg[transformName]
                        packageDir = path.dirname packageFile

                        if !config?
                            # Didn't find the config in the package file.  Try the parent dir.
                            parent = path.resolve packageDir, ".."
                            if parent == packageDir
                                # Hit the root - we're done
                                done null, null
                            else
                                findConfig parent

                        else
                            # Found some configuration
                            if typeof config is "string"
                                # Load from an external file
                                try
                                    configData = loadExternalConfig packageFile, config
                                catch err
                                    return done err

                            else
                                configFile = packageFile
                                configDir = packageDir
                                configData = {config, configDir, configFile, packageFile, cached: false}
                            storeConfigInCache transformName, packageFile, configData
                            done null, configData

    findConfig dir


# Synchronous version of `loadTransformConfig()`.  Returns `{config, configDir}`.
exports.loadTransformConfigSync = (transformName, file) ->
    configData = null

    dirname = path.dirname file

    done = false
    while !done
        packageFile = findPackageJsonSync dirname

        if !packageFile?
            # Couldn't find configuration
            configData = null
            done = true

        else
            configData = getConfigFromCache transformName, packageFile

            if configData
                done = true
            else
                pkg = require packageFile
                config = pkg[transformName]
                packageDir = path.dirname packageFile

                if !config?
                    # Didn't find the config in the package file.  Try the parent dir.
                    dirname = path.resolve packageDir, ".."
                    if dirname == packageDir
                        # Hit the root - we're done
                        done = true
                else
                    # Found some configuration
                    if typeof config is "string"
                        # Load from an external file
                        configData = loadExternalConfig packageFile, config
                    else
                        configFile = packageFile
                        configDir = packageDir
                        configData = {config, configDir, configFile, packageFile, cached: false}

                    storeConfigInCache transformName, packageFile, configData
                    done = true

    return configData

exports.clearConfigCache = ->
    packageJsonCache = {}
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
