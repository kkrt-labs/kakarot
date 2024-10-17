use core::fmt::Formatter;

pub trait JsonMut<T> {
    fn to_json(ref self: T) -> ByteArray;
}

pub trait Json<T> {
    fn to_json(self: @T) -> ByteArray;
}

impl TupleTwoJson<T1, T2, +Destruct<T1>, +Json<T1>, +Destruct<T2>, +Json<T2>> of Json<(T1, T2)> {
    fn to_json(self: @(T1, T2)) -> ByteArray {
        let (t1, t2) = self;
        format!("[{}, {}]", t1.to_json(), t2.to_json())
    }
}

impl TupleThreeJson<T1, T2, T3, +Destruct<T1>, +Json<T1>, +Destruct<T2>, +Json<T2>, +Destruct<T3>, +Json<T3>> of Json<(T1, T2, T3)> {
    fn to_json(self: @(T1, T2, T3)) -> ByteArray {
        let (t1, t2, t3) = self;
        format!("[{}, {}, {}]", t1.to_json(), t2.to_json(), t3.to_json())
    }
}

impl TupleTwoJsonMut<T1, T2, +Destruct<T1>, +JsonMut<T1>, +Destruct<T2>, +Json<T2>> of JsonMut<(T1, T2)> {
    fn to_json(ref self: (T1, T2)) -> ByteArray {
        let (mut t1, mut t2) = self;
        let res = format!("[{}, {}]", t1.to_json(), t2.to_json());
        self = (t1, t2);
        res
    }
}

impl TupleThreeJsonMut<T1, T2, T3, +Destruct<T1>, +JsonMut<T1>, +Destruct<T2>, +JsonMut<T2>, +Destruct<T3>, +JsonMut<T3>> of JsonMut<(T1, T2, T3)> {
    fn to_json(ref self: (T1, T2, T3)) -> ByteArray {
        let (mut t1, mut t2, mut t3) = self;
        let res = format!("[{}, {}, {}]", t1.to_json(), t2.to_json(), t3.to_json());
        self = (t1, t2, t3);
        res
    }
}

impl SpanJSON<T, +core::fmt::Display<T>, +Drop<T>, +Copy<T>, +Json<T>, +PartialEq<T>> of Json<Span<T>> {
    fn to_json(self: @Span<T>) -> ByteArray {
        let self = *self;
        let mut json: ByteArray = "";
        let mut formatter = Formatter { buffer: json };
        write!(formatter, "[").expect('JSON formatting failed');
        for value in self {
            let value = *value;
            write!(formatter, "{}", value.to_json()).expect('JSON formatting failed');
            if value != *self.at(self.len() - 1) {
                write!(formatter, ", ").expect('JSON formatting failed');
            }
        };
        write!(formatter, "]").expect('JSON formatting failed');
        formatter.buffer
    }
}

impl SpanJsonMut<T, +core::fmt::Display<T>, +Drop<T>, +Copy<T>, +JsonMut<T>, +PartialEq<T>> of JsonMut<Span<T>> {
    fn to_json(ref self: Span<T>) -> ByteArray {
        self.to_json()
    }
}



impl U256Json = integer_json::IntegerJSON<u256>;
impl U128Json = integer_json::IntegerJSON<u128>;
impl U64Json = integer_json::IntegerJSON<u64>;
impl U32Json = integer_json::IntegerJSON<u32>;
impl U16Json = integer_json::IntegerJSON<u16>;
impl U8Json = integer_json::IntegerJSON<u8>;

pub mod integer_json {
    use super::Json;

    pub(crate) impl IntegerJSON<T, +core::fmt::Display<T>, +Drop<T>, +Copy<T>> of Json<T> {
        fn to_json(self: @T) -> ByteArray {
            format!("{}", *self)
        }
    }
}
