// <autogenerated>
//   This file was generated by dddappp code generator.
//   Any changes made to this file manually will be lost next time the file is regenerated.
// </autogenerated>

module aptos_blog_demo::comment_added {

    use aptos_blog_demo::article::{Self, CommentAdded};
    use std::string::String;

    public fun article_id(comment_added: &CommentAdded): u128 {
        article::comment_added_article_id(comment_added)
    }

    public fun comment_seq_id(comment_added: &CommentAdded): u64 {
        article::comment_added_comment_seq_id(comment_added)
    }

    public fun commenter(comment_added: &CommentAdded): String {
        article::comment_added_commenter(comment_added)
    }

    public fun body(comment_added: &CommentAdded): String {
        article::comment_added_body(comment_added)
    }

    public fun owner(comment_added: &CommentAdded): address {
        article::comment_added_owner(comment_added)
    }

}
