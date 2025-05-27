import pytest
from unittest.mock import Mock, patch
from assistant import Assistant

@pytest.fixture
def mock_response():
    return {
        "choices": [
            {
                "message": {
                    "content": "Test commit message"
                }
            }
        ]
    }

@pytest.fixture
def assistant():
    return Assistant(api_url="http://test.com", api_key="test-key")

def test_assistant_initialization():
    assistant = Assistant(api_url="http://test.com", api_key="test-key")
    assert assistant.api_url == "http://test.com"
    assert assistant.api_key == "test-key"

@patch('assistant.httpx.post')
def test_assist_success(mock_post, assistant, mock_response):
    mock_post.return_value.json.return_value = mock_response
    mock_post.return_value.status_code = 200
    
    result = assistant.assist("test diff", "test prompt", "test model")
    
    assert result == "Test commit message"
    mock_post.assert_called_once()

@patch('assistant.httpx.post')
def test_assist_error(mock_post, assistant):
    mock_post.return_value.status_code = 400
    mock_post.return_value.text = "Error message"
    
    with pytest.raises(Exception) as exc_info:
        assistant.assist("test diff", "test prompt", "test model")
    
    assert "Error message" in str(exc_info.value) 