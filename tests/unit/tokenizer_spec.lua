local CME = require("cme")
local H = CME.__INTERNAL_H

describe("tokenizer", function()
        it("identifies simple executables", function()
                assert.are_equal("make", H.get_executable("make"))
                assert.are_equal("gcc", H.get_executable("gcc main.c"))
        end)

        it("identifies terminal subject in shell chains", function()
                assert.are_equal("test", H.get_executable("make && ./test"))
                assert.are_equal("grep", H.get_executable("ls | grep foo"))
                assert.are_equal("make", H.get_executable("cd src; make"))
        end)

        it("respects quotes for internal separators", function()
                assert.are_equal("rg", H.get_executable('rg "foo ; bar"'))
                assert.are_equal("grep", H.get_executable("grep '||' file"))
        end)

        it("handles spaces in quoted paths", function()
                assert.are_equal("make.exe", H.get_executable('"C:/Program Files/make.exe" -j4'))
        end)

        it("bypasses bridge commands and flags", function()
                assert.are_equal("make", H.get_executable("sudo -S make"))
                assert.are_equal("make", H.get_executable("sudo -u root -S make"))

                assert.are_equal("grep", H.get_executable("find . | xargs grep foo"))
                assert.are_equal("gcc", H.get_executable("xargs -I {} gcc {}"))
        end)

        it("normalizes paths to basenames", function()
                assert.are_equal("gcc", H.get_executable("/usr/bin/gcc main.c"))
                assert.are_equal("make", H.get_executable("'./build/make' -C ."))
        end)

        it("returns nil when no candidate is found", function()
                assert.is_nil(H.get_executable("sudo -S"))
                assert.is_nil(H.get_executable("&&"))
                assert.is_nil(H.get_executable(""))
        end)
end)
