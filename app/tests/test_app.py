from fastapi.testclient import TestClient

from app.main import app

client = TestClient(app)

def test_read_root():
    """Проверка root"""
    response = client.get("/")
    assert response.status_code == 200
    assert response.json() == {"message": "Hello, World!"}

def test_health_check():
    """Проверка health"""
    response = client.get("/health")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}

def test_get_users():
    """Проверка получения списка пользователей"""
    response = client.get("/api/users")
    assert response.status_code == 200
    assert "users" in response.json()
    assert len(response.json()["users"]) == 2

def test_create_user_success():
    """Успешное создание пользователя с валидными данными"""
    valid_data = {
        "name": "Alex",
        "surname": "Smirnov",
        "requiredField": "Важная информация",
        "optionalField": "Необязательное примечание"
    }
    response = client.post("/api/users", json=valid_data)
    assert response.status_code == 201
    
    data = response.json()
    assert data["id"] == 3
    assert data["name"] == "Alex"
    assert data["optionalField"] == "Необязательное примечание"

def test_create_user_validation_error():
    """Проверка валидации: ошибка, если в имени есть цифры"""
    invalid_data = {
        "name": "Alex123",
        "surname": "Smirnov",
        "requiredField": "Данные"
    }
    response = client.post("/api/users", json=invalid_data)
    assert response.status_code == 422 

def test_create_user_missing_required_field():
    """Проверка валидации: ошибка, если пропущено обязательное поле"""
    invalid_data = {
        "name": "Alex",
        "surname": "Smirnov"
        # requiredField
    }
    response = client.post("/api/users", json=invalid_data)
    assert response.status_code == 422

def test_delete_user_success():
    """Успешное удаление существующего пользователя"""
    response = client.delete("/api/users/1")
    assert response.status_code == 200
    assert "deleted successfully" in response.json()["message"]

def test_delete_user_not_found():
    """Ошибка 404 при удалении несуществующего пользователя"""
    response = client.delete("/api/users/999")
    assert response.status_code == 404
