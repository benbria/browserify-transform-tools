transformTools = require '../src/transformTools'
browserify = require 'browserify'
path = require 'path'
assert = require 'assert'

dummyJsonFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.json"
dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"
testDir = path.resolve __dirname, "../testFixtures/testWithConfig"

describe "transformTools skipping files", ->
    verifyRunsOnJsAndNotJson = (transform, done) ->
        content = "this is a blue test"
        expectedContent = "this is a red test"

        transformTools.runTransform transform, dummyJsonFile, {content}, (err, result) ->
            return done err if err
            # No change for json file
            assert.equal result, content

            transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
                return done err if err
                # Change for js file
                assert.equal result, expectedContent

            done()

    it "should exclude files by extension", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            excludeExtensions: ['.json']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');
        verifyRunsOnJsAndNotJson transform, done


    it "should include files by extension", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            includeExtensions: ['.js']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');
        verifyRunsOnJsAndNotJson transform, done

    it "should include files by extension, with multiple extensions", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            includeExtensions: ['.js', '.coffee']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, 'red');
        verifyRunsOnJsAndNotJson transform, done
