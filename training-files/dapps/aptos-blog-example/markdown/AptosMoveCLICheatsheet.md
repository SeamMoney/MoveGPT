# Aptos Move CLI Cheatsheet

[ToC]

## Article aggregate

### Create method

```shell
aptos move run --function-id 'default::article_aggregate::create' \
--args 'string:title' 'string:body' address:owner \
--assume-yes
```

### Update method

```shell
aptos move run --function-id 'default::article_aggregate::update' \
--args u128:article_id 'string:title' 'string:body' address:owner \
--assume-yes
```

### Delete method

```shell
aptos move run --function-id 'default::article_aggregate::delete' \
--args u128:article_id \
--assume-yes
```

### AddComment method

```shell
aptos move run --function-id 'default::article_aggregate::add_comment' \
--args u128:article_id 'string:commenter' 'string:body' address:owner \
--assume-yes
```

### RemoveComment method

```shell
aptos move run --function-id 'default::article_aggregate::remove_comment' \
--args u128:article_id u64:comment_seq_id \
--assume-yes
```

### UpdateComment method

```shell
aptos move run --function-id 'default::article_aggregate::update_comment' \
--args u128:article_id u64:comment_seq_id 'string:commenter' 'string:body' address:owner \
--assume-yes
```

## BlogState singleton object

### Create method

```shell
aptos move run --function-id 'default::blog_state_aggregate::create' \
--args 'string:name' bool:is_emergency \
--assume-yes
```

### Update method

```shell
aptos move run --function-id 'default::blog_state_aggregate::update' \
--args 'string:name' 'vector<u128>:articles_item_1,articles_item_2' bool:is_emergency \
--assume-yes
```

### Delete method

```shell
aptos move run --function-id 'default::blog_state_aggregate::delete' \
--assume-yes
```

