class Book {
  final int? bookId;
  final String title;
  final String author;
  final String bookCategories;
  final String description;
  final String? fileUrl;
  final int? fileSize;
  final int likeCounter;
  final String? language;
  final int? publishYear;
  final String? imageUrl;

  Book({
    this.bookId,
    required this.title,
    required this.author,
    required this.bookCategories,
    required this.description,
    this.fileUrl,
    this.fileSize,
    this.likeCounter = 0,
    this.language,
    this.publishYear,
    this.imageUrl,
  });

  factory Book.fromMap(Map<String, dynamic> map) {
  return Book(
    bookId: map['book_id'] as int?,
    title: map['title'] ?? '',
    author: map['author'] ?? '',
    bookCategories: map['book_categories'] ?? '',
    description: map['description'] ?? '',
    fileUrl: map['file_url'],
    fileSize: map['file_size'] as int?,
    likeCounter: map['like_counter'] ?? 0,
    language: map['language'],
    publishYear: map['publish_year'] as int?,
    imageUrl: map['image_url'],
  );
}

}
