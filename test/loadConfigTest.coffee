transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"

describe "transformTools configuration loading", ->
    it "should load configuration from package.json", (done) ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfig "unblueify", dummyJsFile, (err, config, configDir) ->
            assert.equal config.color, "red"
            assert.equal configDir, path.resolve __dirname, "../testFixtures/testWithConfig"

            # Verify we load correctly from the cache
            config = transformTools.loadTransformConfig "unblueify", dummyJsFile, (err, config, configDir) ->
                assert.equal config.color, "red"
                assert.equal configDir, path.resolve __dirname, "../testFixtures/testWithConfig"
                done()

    it "should load configuration from a js file", (done) ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfig "unyellowify", dummyJsFile, (err, config, configDir) ->
            assert.equal config.color, "green"
            assert.equal configDir, path.resolve __dirname, "../testFixtures/testWithConfig/yellow"
            done()

    it "should fail to load configuration for a transform that doesn't exist", (done) ->
        transformTools.clearConfigCache()
        config = transformTools.loadTransformConfig "iDontExistify", dummyJsFile, (err, config, configDir) ->
            assert.equal config, null
            done()

    it "should load configuration synchronously from package.json", ->
        transformTools.clearConfigCache()
        {config, configDir} = transformTools.loadTransformConfigSync "unblueify", dummyJsFile
        assert.equal config.color, "red"
        assert.equal configDir, path.resolve __dirname, "../testFixtures/testWithConfig"

        # Verify we load correctly from the cache
        {config, configDir} = transformTools.loadTransformConfigSync "unblueify", dummyJsFile
        assert.equal config.color, "red"
        assert.equal configDir, path.resolve __dirname, "../testFixtures/testWithConfig"

    it "should load configuration synchronously from a js file", ->
        transformTools.clearConfigCache()
        {config, configDir} = transformTools.loadTransformConfigSync "unyellowify", dummyJsFile
        assert.equal config.color, "green"
        assert.equal configDir, path.resolve __dirname, "../testFixtures/testWithConfig/yellow"

    it "should fail to load configuration synchronously for a transform that doesn't exist", ->
        transformTools.clearConfigCache()
        {config, configDir} = transformTools.loadTransformConfigSync "iDontExistify", dummyJsFile
        assert.equal config, null
