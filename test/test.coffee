transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"

describe "transformTools", ->
    it "load configuration from package.json", ->
        config = transformTools.loadTransformConfigSync "unblueify", dummyJsFile
        assert.equal config.color, "red"

    it "load configuration from a js file", ->
        config = transformTools.loadTransformConfigSync "unyellowify", dummyJsFile
        assert.equal config.color, "green"

    it "should transform generate a transform that operates on a string", (done) ->
        transform = transformTools.makeStringTransform "unblueify", (content, opts) ->
            return content.replace(/blue/g, opts.config.color);

        content = "this is a blue test"
        expectedContent = "this is a red test"

        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()

    it "should transform generate a transform that uses falafel", (done) ->
        transform = transformTools.makeFalafelTransform "unyellowify", (node, opts) ->
            if node.type is "ArrayExpression"
                node.update "#{opts.config.color}(#{node.source()})"

        content = "var x = [1,2,3];"
        expectedContent = "var x = green([1,2,3]);"
        transformTools.runTransform transform, dummyJsFile, {content}, (err, result) ->
            return done err if err
            assert.equal result, expectedContent
            done()