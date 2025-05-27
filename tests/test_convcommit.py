import pytest
from unittest.mock import Mock, patch
from io import StringIO
from convcommit import main

@pytest.fixture
def mock_diff_generator():
    with patch('convcommit.DiffGenerator') as mock:
        mock.return_value.generate.return_value = "test diff"
        yield mock

@pytest.fixture
def mock_assistant():
    with patch('convcommit.Assistant') as mock:
        instance = Mock()
        instance.assist.return_value = "Test commit message"
        mock.return_value = instance
        yield mock

@pytest.fixture
def mock_runner():
    with patch('convcommit.Runner') as mock:
        instance = Mock()
        instance.generate.return_value = "Test commit message"
        mock.return_value = instance
        yield mock

def test_main_with_repository_path(mock_diff_generator, mock_assistant, mock_runner):
    with patch('convcommit.click.echo') as mock_echo:
        main(
            repository_path="/test/repo",
            prompt_file="test_prompt.md",
            model="test-model",
            openai_api_key="test-key",
            base_url="http://test.com",
            diff_from_stdin=None,
            debug_diff=False,
            max_bytes_in_diff=1024,
            verbose=False
        )
        
        mock_echo.assert_called_with("Test commit message")

def test_main_with_stdin(mock_assistant, mock_runner):
    with patch('convcommit.click.echo') as mock_echo:
        stdin = StringIO("test diff")
        main(
            repository_path=None,
            prompt_file="test_prompt.md",
            model="test-model",
            openai_api_key="test-key",
            base_url="http://test.com",
            diff_from_stdin=stdin,
            debug_diff=False,
            max_bytes_in_diff=1024,
            verbose=False
        )
        
        mock_echo.assert_called_with("Test commit message")

def test_main_no_input():
    with pytest.raises(SystemExit) as exc_info:
        main(
            repository_path=None,
            prompt_file="test_prompt.md",
            model="test-model",
            openai_api_key="test-key",
            base_url="http://test.com",
            diff_from_stdin=None,
            debug_diff=False,
            max_bytes_in_diff=1024,
            verbose=False
        )
    
    assert exc_info.value.code == 1 