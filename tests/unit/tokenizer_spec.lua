local cme = require("cme")
local H = cme.__INTERNAL_H

describe("tokenizer", function()
        it("identifies simple executables", function()
                assert.are.equal("make", H.get_executable("make"))
                assert.are.equal("gcc", H.get_executable("gcc main.c"))
        end)

        it("identifies terminal subject in shell chains", function()
                assert.are.equal("test", H.get_executable("make && ./test"))
                assert.are.equal("grep", H.get_executable("ls | grep foo"))
                assert.are.equal("make", H.get_executable("cd src; make"))
        end)

        it("respects quotes for internal separators", function()
                assert.are.equal("rg", H.get_executable('rg "foo ; bar"'))
                assert.are.equal("grep", H.get_executable("grep '||' file"))
        end)

        it("handles spaces in quoted paths", function()
                assert.are.equal("make.exe", H.get_executable('"C:/Program Files/make.exe" -j4'))
        end)

        it("bypasses bridge commands and flags", function()
                assert.are.equal("make", H.get_executable("sudo -S make"))
                assert.are.equal("make", H.get_executable("sudo -u root -S make"))

                assert.are.equal("grep", H.get_executable("find . | xargs grep foo"))
                assert.are.equal("gcc", H.get_executable("xargs -I {} gcc {}"))
        end)

        it("normalizes paths to basenames", function()
                assert.are.equal("gcc", H.get_executable("/usr/bin/gcc main.c"))
                assert.are.equal("make", H.get_executable("'./build/make' -C ."))
        end)

        it("returns nil when no candidate is found", function()
                assert.is_nil(H.get_executable("sudo -S"))
                assert.is_nil(H.get_executable("&&"))
                assert.is_nil(H.get_executable(""))
        end)
end)
