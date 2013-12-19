transformTools = require '../src/transformTools'
path = require 'path'
assert = require 'assert'

dummyJsFile = path.resolve __dirname, "../testFixtures/testWithConfig/dummy.js"

describe "transformTools falafel transforms", ->
    it "should generate a transform that uses falafel", (done) ->
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

    it "should return an error when falafel transform throws an error", (done) ->
        transform = transformTools.makeFalafelTransform "unyellowify", (node, opts, cb) ->
            throw new Error("foo")

        transformTools.runTransform transform, dummyJsFile, {content:"lala"}, (err, result) ->
            assert.equal err?.message, "foo (while processing /Users/jwalton/benbria/browserify-transform-tools/testFixtures/testWithConfig/dummy.js)"
            done()
