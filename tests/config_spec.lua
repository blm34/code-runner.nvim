local vim_mock = require("helpers.vim_mock")

describe("code-runner.config", function()
    local config

    before_each(function()
        vim_mock.setup()
        package.loaded["code-runner.config"] = nil
        config = require("code-runner.config")
    end)

    after_each(function()
        vim_mock.teardown()
    end)

    describe("defaults", function()
        it("has max_slots = 3", function()
            assert.equal(3, config.defaults.max_slots)
        end)

        it("has slot_id_offset = 100", function()
            assert.equal(100, config.defaults.slot_id_offset)
        end)

        it("has busy_behaviour = 'ask'", function()
            assert.equal("ask", config.defaults.busy_behaviour)
        end)

        it("has interrupt_delay_ms = 100", function()
            assert.equal(100, config.defaults.interrupt_delay_ms)
        end)

        it("has python venv_names list", function()
            assert.is_table(config.defaults.runners.python.venv_names)
            assert.is_true(#config.defaults.runners.python.venv_names > 0)
        end)

        it("includes common python venv directory names", function()
            local names = config.defaults.runners.python.venv_names
            local set = {}
            for _, n in ipairs(names) do set[n] = true end
            assert.is_true(set[".venv"])
            assert.is_true(set["venv"])
        end)
    end)

    describe("setup() with no opts", function()
        it("leaves options equal to defaults when called with no args", function()
            config.setup()
            assert.equal(config.defaults.max_slots, config.options.max_slots)
            assert.equal(config.defaults.slot_id_offset, config.options.slot_id_offset)
            assert.equal(config.defaults.interrupt_delay_ms, config.options.interrupt_delay_ms)
        end)

        it("leaves options equal to defaults when called with empty table", function()
            config.setup({})
            assert.equal(config.defaults.max_slots, config.options.max_slots)
            assert.equal(config.defaults.slot_id_offset, config.options.slot_id_offset)
            assert.equal(config.defaults.interrupt_delay_ms, config.options.interrupt_delay_ms)
        end)
    end)

    describe("setup() with opts", function()
        it("overrides max_slots", function()
            config.setup({ max_slots = 5 })
            assert.equal(5, config.options.max_slots)
        end)

        it("overrides busy_behaviour", function()
            config.setup({ busy_behaviour = "interrupt" })
            assert.equal("interrupt", config.options.busy_behaviour)
        end)

        it("accepts all valid busy_behaviour values", function()
            for _, value in ipairs({ "ask", "cancel", "interrupt", "new" }) do
                config.setup({ busy_behaviour = value })
                assert.equal(value, config.options.busy_behaviour)
            end
        end)

        it("overrides interrupt_delay_ms", function()
            local opts = { interrupt_delay_ms = 250 }
            config.setup(opts)
            assert.equal(250, config.options.interrupt_delay_ms)
        end)

        it("deep merges runner config", function()
            config.setup({ runners = { python = { venv_names = { "myenv" } } } })
            assert.same({ "myenv" }, config.options.runners.python.venv_names)
        end)

        it("preserves unspecified runner config when only some keys overridden", function()
            -- slot_id_offset not overridden, should stay at default
            config.setup({ max_slots = 2 })
            assert.equal(100, config.options.slot_id_offset)
        end)
    end)

    describe("max_slots clamping", function()
        it("clamps max_slots to 9 if value > 9", function()
            config.setup({ max_slots = 15 })
            assert.equal(9, config.options.max_slots)
        end)

        it("emits a WARN notification when clamping", function()
            local level_seen
            vim_mock.get().notify = function(_, level) level_seen = level end
            config.setup({ max_slots = 10 })
            assert.equal(vim_mock.get().log.levels.WARN, level_seen)
        end)

        it("does not clamp or notify when max_slots == 9", function()
            local notified = false
            vim_mock.get().notify = function() notified = true end

            config.setup({ max_slots = 9 })

            assert.equal(9, config.options.max_slots)
            assert.is_false(notified)
        end)

        it("does not clamp when max_slots is within range", function()
            config.setup({ max_slots = 5 })
            assert.equal(5, config.options.max_slots)
        end)
    end)

    describe("options isolation", function()
        it("does not mutate defaults when setup() is called", function()
            config.setup({ max_slots = 7 })
            assert.equal(3, config.defaults.max_slots)
        end)
    end)
end)
