# Backend

A Lightweight Backend impl using tai_shang_micro_faas.

See in `gist`: 

> **Snippet:** https://gist.github.com/leeduckgo/707eb037b11d3786680c621aaadc018d

> **FaaS:** https://faasbyleeduckgo.gigalixirapp.com/

* `get_all_crowdfund`

```
curl --location --request POST 'https://faasbyleeduckgo.gigalixirapp.com/api/v1/run' \
--header 'Content-Type: application/json' \
--data-raw '{
    "name": "MoveCrowdfund",
    "func_name": "get_all_crowdfund",
    "params": []
}' | jq 
```
