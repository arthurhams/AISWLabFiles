$postdata = Get-Content -Path .\testdata.json 
$port =Read-Host -Prompt "Enter your port number"
$url = "http://localhost:$port/api/Transform"
$response = Invoke-WebRequest -Uri $url -Method Post -Body $postdata
$response.RawContent