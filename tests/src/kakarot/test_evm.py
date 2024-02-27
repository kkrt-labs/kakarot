class TestInstructions:
    def test__unknown_opcode(self, cairo_run):
        evm = cairo_run("test__unknown_opcode")
        assert evm["return_data"] == list(b"Kakarot: UnknownOpcode")
