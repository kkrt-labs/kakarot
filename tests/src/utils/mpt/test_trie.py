def test_patricialize(cairo_run):
    cairo_run("test__patricialize", objects={b"doge": b"coins"})


def test_find_shortest_common_prefix(cairo_run):
    res = cairo_run(
        "test__find_shortest_common_prefix",
        objects={b"doge": b"coins"},
        substring=b"dog",
    )
    assert res == 3
