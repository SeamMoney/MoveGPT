```rust
// <autogenerated>
//   This file was generated by dddappp code generator.
//   Any changes made to this file manually will be lost next time the file is regenerated.
// </autogenerated>

module aptos_blog_demo::article_created {

    use aptos_blog_demo::article::{Self, ArticleCreated};
    use std::string::String;

    public fun article_id(article_created: &ArticleCreated): u128 {
        article::article_created_article_id(article_created)
    }

    public fun title(article_created: &ArticleCreated): String {
        article::article_created_title(article_created)
    }

    public fun body(article_created: &ArticleCreated): String {
        article::article_created_body(article_created)
    }

    public fun owner(article_created: &ArticleCreated): address {
        article::article_created_owner(article_created)
    }

}

```