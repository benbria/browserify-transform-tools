path = require 'path'
assert = require 'assert'

browserify = require 'browserify'
async = require 'async'

transformTools = require '../src/transformTools'
skipFile = require '../src/skipFile'

dummyJsonFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.json"
dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"
testDir = path.resolve __dirname, "../testFixtures/testWithConfig"

describe "transformTools skipping files", ->
    cwd = process.cwd()

    beforeEach ->
        process.chdir testDir

    after ->
        process.chdir cwd

    verifyExtensions = (transform, includedExtensions, skippedExtensions, done) ->
        content = "this is a blue test"
        expectedContent = "this is a red test"

        checkRuns = (shouldRun) ->
            (ext, done2) ->
                dummyFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy#{ext}"
                transformTools.runTransform transform, dummyFile, {content}, (err, result) ->
                    return done2 err if err
                    if shouldRun
                        assert result == expectedContent, "Should transform #{ext}"
                    else
                        assert result == content, "Should not transform #{ext}"
                    done2()

        async.each includedExtensions, checkRuns(true), (err) ->
            return done err if err
            async.each skippedExtensions, checkRuns(false), (err) ->
                done err


    it "should exclude files by extension", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            excludeExtensions: ['.json']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');
        verifyExtensions transform, ['.js'], ['.json'], done

    it "should include files by extension", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            includeExtensions: ['.js']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');
        verifyExtensions transform, ['.js'], ['.json'], done

    it "should include files by extension, with multiple extensions", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            includeExtensions: ['.js', '.coffee']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');
        verifyExtensions transform, ['.js'], ['.json'], done

    it "should respect includeExtensions overrides from config from transform", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            includeExtensions: ['.js']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');

        transform = transform.configure {
            appliesTo: includeExtensions: ['.json']
        }
        verifyExtensions transform, ['.json'], ['.js'], done

    it "should respect 'includeExtensions' overrides from config", ->
        options = {
            appliesTo: includeExtensions: ['.js']

        }
        configData = {
            appliesTo: includeExtensions: ['.json']
        }
        assert skipFile("foo.js", configData, options), "Should skip .js files"
        assert !skipFile("foo.json", configData, options), "Should not skip .json files"

    it "should respect 'exclueExtensions' overrides from config", ->
        options = {
            appliesTo: includeExtensions: ['.js']

        }
        configData = {
            appliesTo: excludeExtensions: ['.js']
        }
        assert skipFile("foo.js", configData, options), "Should skip .js files"
        assert !skipFile("foo.json", configData, options), "Should not skip .json files"

    it "should respect 'files' from config", ->
        options = {
            appliesTo: includeExtensions: ['.js']

        }
        configData = {
            configDir: '.'
            appliesTo: files: ['foo.json', './bar/bar.json']
        }
        assert skipFile("foo.js", configData, options), "Should skip foo.js"
        assert !skipFile("foo.json", configData, options), "Should not skip foo.json"
        assert skipFile("./bar/foo.json", configData, options), "Should skip ./bar/foo.json"
        assert !skipFile("./bar/bar.json", configData, options), "Should not skip ./bar/bar.json"
        assert !skipFile("bar/bar.json", configData, options), "Should not skip bar/bar.json"

    it "should respect 'regex' from config", ->
        options = {
            appliesTo: includeExtensions: ['.js']
        }
        configData = {
            configDir: '.'
            appliesTo: regex: ".*\\.json"
        }
        assert skipFile("foo.js", configData, options), "Should skip foo.js"
        assert !skipFile("foo.json", configData, options), "Should not skip foo.json"

    it "should respect `files` from config file", (done) ->
        transform = transformTools.makeStringTransform "applyToExtify", {
            includeExtensions: ['.js']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');

        content = "this is a blue test"
        expectedContent = "this is a red test"

        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert result == content, "Should not transform #{dummyJsFile}"
            dummyGreenJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/green.js"
            transformTools.runTransform transform, dummyGreenJsFile, {content}, (err, result) ->
                return done err if err
                assert result == expectedContent, "Should transform #{dummyGreenJsFile}"
                done()



