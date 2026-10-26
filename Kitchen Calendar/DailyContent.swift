import Foundation

/// A new trivia fact and quote each day.
enum DailyContent {
    static let trivia = [
        "Octopuses have three hearts and blue blood.",
        "A day on Venus is longer than its year: it spins once every 243 Earth days but circles the Sun in 225.",
        "Botanically speaking, bananas are berries and strawberries are not.",
        "The Eiffel Tower grows about 15 cm taller in summer as its iron expands in the heat.",
        "Sharks were swimming the oceans before the first trees grew on land.",
        "Wombats produce cube-shaped droppings.",
        "The shortest war on record, between Britain and Zanzibar in 1896, lasted under 45 minutes.",
        "A group of flamingos is called a flamboyance.",
        "Cleopatra lived closer in time to the Moon landing than to the building of the Great Pyramid.",
        "Sea otters hold hands while they sleep so they don’t drift apart.",
        "Scotland’s national animal is the unicorn.",
        "Saturn is less dense than water. In a big enough bathtub, it would float.",
        "Butterflies taste with sensors on their feet.",
        "A bolt of lightning is about five times hotter than the surface of the Sun.",
        "Oxford University was already teaching students before the Aztec capital Tenochtitlan was founded.",
        "The dot over a lowercase i or j is called a tittle.",
        "Honey never really spoils. Pots found in ancient Egyptian tombs were still edible.",
        "An ostrich’s eye is bigger than its brain."
    ]

    static let quotes: [(text: String, author: String)] = [
        ("Well done is better than well said.", "Benjamin Franklin"),
        ("Act as if what you do makes a difference. It does.", "William James"),
        ("Nothing in life is to be feared, it is only to be understood.", "Marie Curie"),
        ("The best way out is always through.", "Robert Frost"),
        ("The journey of a thousand miles begins with a single step.", "Lao Tzu"),
        ("Do what you can, with what you have, where you are.", "Theodore Roosevelt"),
        ("Fall seven times, stand up eight.", "Japanese proverb"),
        ("The only way to have a friend is to be one.", "Ralph Waldo Emerson"),
        ("Kind words do not cost much. Yet they accomplish much.", "Blaise Pascal"),
        ("Little by little, one travels far.", "Spanish proverb")
    ]

    private static func dayNumber(_ date: Date) -> Int {
        Calendar.current.ordinality(of: .day, in: .year, for: date) ?? 1
    }

    static func trivia(for date: Date) -> String {
        trivia[(dayNumber(date) * 7) % trivia.count]
    }

    static func quote(for date: Date) -> (text: String, author: String) {
        quotes[dayNumber(date) % quotes.count]
    }
}
