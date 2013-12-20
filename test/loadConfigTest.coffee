transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"

describe "transformTools configuration loading", ->
    it "should load configuration from package.json", (done) ->
        transformTools.clearConfigCache()
        transformTools.loadTransformConfig "unblueify", dummyJsFile, (err, configData) ->
            return done err if err
            assert configData, "Config found"
            assert.equal configData.cached, false
            assert.equal configData.config.color, "red"
            assert.equal configData.configDir, path.resolve __dirname, "../testFixtures/testWithConfig"
            assert.equal configData.configFile, path.resolve __dirname, "../testFixtures/testWithConfig/package.json"

            # Verify we load correctly from the cache
            config = transformTools.loadTransformConfig "unblueify", dummyJsFile, (err, configData) ->
                return done err if err
                assert configData, "Config found"
                assert.equal configData.cached, true
                assert.equal configData.config.color, "red"
                assert.equal configData.configDir, path.resolve __dirname, "../testFixtures/testWithConfig"
                assert.equal configData.configFile, path.resolve __dirname, "../testFixtures/testWithConfig/package.json"
                done()

    it "should load configuration from a js file", (done) ->
        transformTools.clearConfigCache()
        transformTools.loadTransformConfig "unyellowify", dummyJsFile, (err, configData) ->
            return done err if err
            assert configData, "Config found"
            assert.equal configData.config.color, "green"
            assert.equal configData.configDir, path.resolve __dirname, "../testFixtures/testWithConfig/yellow"
            done()

    it "should fail to load configuration for a transform that doesn't exist", (done) ->
        transformTools.clearConfigCache()
        transformTools.loadTransformConfig "iDontExistify", dummyJsFile, (err, configData) ->
            return done err if err
            assert.equal configData, null
            done()

    it "should not continue up the tree if package.json is found", (done) ->
        transformTools.clearConfigCache()
        childPackageJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/childPackage/dummy.js"
        transformTools.loadTransformConfig "unblueify", childPackageJsFile, (err, configData) ->
            return done err if err
            assert configData, "Config found"
            assert.equal configData.config.color, "orange"
            done()

    it "should continue up the tree if package.json doesn't contain configuration", (done) ->
        transformTools.clearConfigCache()
        childPackageJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/childPackage/dummy.js"
        transformTools.loadTransformConfig "unyellowify", childPackageJsFile, (err, configData) ->
            return done err if err
            assert configData, "Config found"
            assert.equal configData.config.color, "green"
            done()

    it "should load configuration synchronously from package.json", ->
        transformTools.clearConfigCache()
        configData = transformTools.loadTransformConfigSync "unblueify", dummyJsFile
        assert configData, "Config found"
        assert.equal configData.cached, false
        assert.equal configData.configDir, path.resolve __dirname, "../testFixtures/testWithConfig"
        assert.equal configData.configFile, path.resolve __dirname, "../testFixtures/testWithConfig/package.json"
        assert.equal configData.config.color, "red"

        # Verify we load correctly from the cache
        configData = transformTools.loadTransformConfigSync "unblueify", dummyJsFile
        assert configData, "Config found"
        assert.equal configData.cached, true
        assert.equal configData.configDir, path.resolve __dirname, "../testFixtures/testWithConfig"
        assert.equal configData.configFile, path.resolve __dirname, "../testFixtures/testWithConfig/package.json"
        assert.equal configData.config.color, "red"

    it "should load configuration synchronously from a js file", ->
        transformTools.clearConfigCache()
        configData = transformTools.loadTransformConfigSync "unyellowify", dummyJsFile
        assert configData, "Config found"
        assert.equal configData.config.color, "green"
        assert.equal configData.configDir, path.resolve __dirname, "../testFixtures/testWithConfig/yellow"

    it "should fail to load configuration synchronously for a transform that doesn't exist", ->
        transformTools.clearConfigCache()
        configData = transformTools.loadTransformConfigSync "iDontExistify", dummyJsFile
        assert.equal configData, null
