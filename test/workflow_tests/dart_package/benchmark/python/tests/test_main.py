from main import main


def test_main_says_hello(capsys):
    main()
    assert "Hello" in capsys.readouterr().out
