import pytest
from unittest.mock import Mock, patch
from runner import Runner
from assistant import Assistant

@pytest.fixture
def mock_assistant():
    return Mock(spec=Assistant)

@pytest.fixture
def runner(mock_assistant):
    return Runner(mock_assistant)

def test_runner_initialization():
    assistant = Mock(spec=Assistant)
    runner = Runner(assistant)
    assert runner.assistant == assistant

@patch('runner.open')
def test_generate_commit_message(mock_open, runner, mock_assistant):
    # Mock file reading
    mock_open.return_value.__enter__.return_value.read.return_value = "Test prompt"
    
    # Mock assistant response
    mock_assistant.assist.return_value = "Test commit message"
    
    result = runner.generate("test diff", "test_prompt.md", "test-model")
    
    assert result == "Test commit message"
    mock_assistant.assist.assert_called_once_with(
        "test diff",
        "Test prompt",
        "test-model"
    )

@patch('runner.open')
def test_generate_commit_message_file_not_found(mock_open, runner):
    mock_open.side_effect = FileNotFoundError
    
    with pytest.raises(FileNotFoundError):
        runner.generate("test diff", "nonexistent.md", "test-model") 