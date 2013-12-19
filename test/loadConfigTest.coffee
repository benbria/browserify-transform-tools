transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"

describe "transformTools configuration loading", ->
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
