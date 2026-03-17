use flutter_rust_bridge::frb;

#[frb]
pub struct FiatCurrency {
    pub code: String,
    pub name: String,
    pub symbol: String,
    pub decimal_digits: i32,
}

#[frb(sync)]
pub fn list_fiat_currencies() -> Vec<FiatCurrency> {
    CURRENCIES
        .iter()
        .map(|&(code, name, symbol, decimal_digits)| FiatCurrency {
            code: code.to_string(),
            name: name.to_string(),
            symbol: symbol.to_string(),
            decimal_digits,
        })
        .collect()
}

#[frb(sync)]
pub fn find_fiat_currency(code: &str) -> Option<FiatCurrency> {
    CURRENCIES
        .iter()
        .find(|&&(c, _, _, _)| c == code)
        .map(|&(code, name, symbol, decimal_digits)| FiatCurrency {
            code: code.to_string(),
            name: name.to_string(),
            symbol: symbol.to_string(),
            decimal_digits,
        })
}

const CURRENCIES: &[(&str, &str, &str, i32)] = &[
    ("ARS", "Argentine Peso", "$", 2),
    ("AUD", "Australian Dollar", "$", 2),
    ("BDT", "Bangladeshi Taka", "৳", 2),
    ("BIF", "Burundian Franc", "FBu", 2),
    ("BOB", "Bolivian Boliviano", "$b", 2),
    ("BRL", "Brazilian Real", "R$", 2),
    ("BTN", "Bhutanese Ngultrum", "Nu.", 2),
    ("BWP", "Botswanan Pula", "P", 2),
    ("CAD", "Canadian Dollar", "$", 2),
    ("CDF", "Congolese Franc", "FC", 2),
    ("CHF", "Swiss Franc", "CHF", 2),
    ("CLP", "Chilean Peso", "$", 0),
    ("CNY", "Chinese Yuan", "¥", 2),
    ("COP", "Colombian Peso", "$", 0),
    ("CRC", "Costa Rican Colón", "₡", 0),
    ("CUP", "Cuban Peso", "$MN", 2),
    ("CZK", "Czech Koruna", "Kč", 2),
    ("DJF", "Djiboutian Franc", "Fdj", 0),
    ("DOP", "Dominican Peso", "RD$", 2),
    ("ERN", "Eritrean Nakfa", "Nfk", 2),
    ("ETB", "Ethiopian Birr", "Br", 2),
    ("EUR", "Euro", "€", 2),
    ("GBP", "British Pound", "£", 2),
    ("GHS", "Ghanaian Cedi", "₵", 2),
    ("GTQ", "Guatemalan Quetzal", "Q", 2),
    ("HKD", "Hong Kong Dollar", "$", 2),
    ("HNL", "Honduran Lempira", "L", 2),
    ("IDR", "Indonesian Rupiah", "Rp", 0),
    ("INR", "Indian Rupee", "₹", 2),
    ("JPY", "Japanese Yen", "¥", 0),
    ("KES", "Kenyan Shilling", "KSh", 2),
    ("KHR", "Cambodian Riel", "៛", 2),
    ("KRW", "South Korean Won", "₩", 0),
    ("LBP", "Lebanese Pound", "ل.ل", 2),
    ("LKR", "Sri Lankan Rupee", "₨", 2),
    ("MMK", "Myanmar Kyat", "Ks", 2),
    ("MWK", "Malawian Kwacha", "MK", 2),
    ("MXN", "Mexican Peso", "$", 2),
    ("MYR", "Malaysian Ringgit", "RM", 2),
    ("MZN", "Mozambican Metical", "MT", 2),
    ("NAD", "Namibian Dollar", "$", 2),
    ("NGN", "Nigerian Naira", "₦", 2),
    ("NIO", "Nicaraguan Córdoba", "C$", 2),
    ("NZD", "New Zealand Dollar", "$", 2),
    ("PAB", "Panamanian Balboa", "B/.", 2),
    ("PEN", "Peruvian Sol", "S/.", 2),
    ("PHP", "Philippine Peso", "₱", 2),
    ("PKR", "Pakistani Rupee", "₨", 0),
    ("PLN", "Polish Zloty", "zł", 2),
    ("PYG", "Paraguayan Guarani", "₲", 0),
    ("RWF", "Rwandan Franc", "FRw", 0),
    ("SDG", "Sudanese Pound", "ج.س", 2),
    ("SOS", "Somali Shilling", "S", 0),
    ("SRD", "Surinamese Dollar", "$", 2),
    ("THB", "Thai Baht", "฿", 2),
    ("TZS", "Tanzanian Shilling", "TSh", 0),
    ("UAH", "Ukrainian Hryvnia", "₴", 2),
    ("UGX", "Ugandan Shilling", "USh", 0),
    ("USD", "United States Dollar", "$", 2),
    ("UYU", "Uruguayan Peso", "$U", 2),
    ("VES", "Venezuelan Bolívar", "Bs", 2),
    ("VND", "Vietnamese Dong", "₫", 0),
    ("XAF", "Central African CFA Franc", "FCFA", 2),
    ("XOF", "West African CFA Franc", "FCFA", 2),
    ("ZAR", "South African Rand", "R", 2),
    ("ZMW", "Zambian Kwacha", "ZK", 2),
    ("ZWL", "Zimbabwean Dollar", "$ZWL", 2),
];
