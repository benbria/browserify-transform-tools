transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"

describe "transformTools", ->
    it "should load configuration from package.json", (done) ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfig "unblueify", dummyJsFile, (err, config) ->
            assert.equal config.color, "red"

            # Verify we load correctly from the cache
            config = transformTools.loadTransformConfig "unblueify", dummyJsFile, (err, config) ->
                assert.equal config.color, "red"
                done()

    it "should load configuration from a js file", (done) ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfig "unyellowify", dummyJsFile, (err, config) ->
            assert.equal config.color, "green"
            done()

    it "should fail to load configuration for a transform that doesn't exist", (done) ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfig "iDontExistify", dummyJsFile, (err, config) ->
            assert.equal config, null
            done()

    it "should load configuration synchronously from package.json", ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfigSync "unblueify", dummyJsFile
        assert.equal config.color, "red"

        # Verify we load correctly from the cache
        config = transformTools.loadTransformConfigSync "unblueify", dummyJsFile
        assert.equal config.color, "red"

    it "should load configuration synchronously from a js file", ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfigSync "unyellowify", dummyJsFile
        assert.equal config.color, "green"

    it "should fail to load configuration synchronously for a transform that doesn't exist", ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfigSync "iDontExistify", dummyJsFile
        assert.equal config, null

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

    it "should transform generate a transform that uses falafel", (done) ->
        transform = transformTools.makeFalafelTransform "unyellowify", (node, opts, cb) ->
            if node.type is "ArrayExpression"
                node.update "#{opts.config.color}(#{node.source()})"
            cb()

        content = "var x = [1,2,3];"
        expectedContent = "var x = green([1,2,3]);"
        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()

    it "should return an error when falafel transform returns an error", (done) ->
        transform = transformTools.makeFalafelTransform "unyellowify", (node, opts, cb) ->
            cb new Error("foo")

        transformTools.runTransform transform, dummyJsFile, {content:"lala"}, (err, result) ->
            assert.equal err?.message, "foo (while processing /Users/jwalton/benbria/browserify-transform-tools/testFixtures/testWithConfig/dummy.js)"
            done()

