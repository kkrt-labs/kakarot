class TestInstructions:
    def test__unknown_opcode(self, cairo_run):
        output = cairo_run("test__unknown_opcode")
        assert output == list(b"Kakarot: UnknownOpcode")
