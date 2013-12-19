transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"
dummyJsonFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.json"

describe "transformTools string transforms", ->
    it "should transform generate a transform that operates on a string", (done) ->
        transform = transformTools.makeStringTransform "unblueify", (content, opts, cb) ->
            cb null, content.replace(/blue/g, opts.config.color);

        content = "this is a blue test"
        expectedContent = "this is a red test"

        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()

    it "should return an error when string transform returns an error", (done) ->
        transform = transformTools.makeStringTransform "unblueify", (content, opts, cb) ->
            cb new Error("foo")

        transformTools.runTransform transform, dummyJsFile, {content:"lala"}, (err, result) ->
            assert.equal err?.message, "foo (while processing /Users/jwalton/benbria/browserify-transform-tools/testFixtures/testWithConfig/dummy.js)"
            done()

    it "should return an error when string transform throws an error", (done) ->
        transform = transformTools.makeStringTransform "unblueify", (content, opts, cb) ->
            throw new Error("foo")

        transformTools.runTransform transform, dummyJsFile, {content:"lala"}, (err, result) ->
            assert.equal err?.message, "foo (while processing /Users/jwalton/benbria/browserify-transform-tools/testFixtures/testWithConfig/dummy.js)"
            done()


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
            cb null, content.replace(/blue/g, opts.config.color);
        verifyRunsOnJsAndNotJson transform, done


    it "should include files by extension", (done) ->
        transform = transformTools.makeStringTransform "unblueify", {
            includeExtensions: ['.js']
        }, (content, opts, cb) ->
            cb null, content.replace(/blue/g, opts.config.color);
        verifyRunsOnJsAndNotJson transform, done
