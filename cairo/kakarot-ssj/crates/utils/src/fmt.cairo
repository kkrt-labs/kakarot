use core::fmt::{Debug, Formatter, Error};
use crate::set::{SpanSet, SpanSetTrait};

mod display_felt252_based {
    use core::fmt::{Display, Formatter, Error};
    use core::to_byte_array::AppendFormattedToByteArray;
    pub impl TDisplay<T, +Into<T, felt252>, +Copy<T>> of Display<T> {
        fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
            let value: felt252 = (*self).into();
            let base: felt252 = 10_u8.into();
            value.append_formatted_to_byte_array(ref f.buffer, base.try_into().unwrap());
            Result::Ok(())
        }
    }
}

mod debug_display_based {
    use core::fmt::{Display, Debug, Formatter, Error};
    pub impl TDisplay<T, +Display<T>> of Debug<T> {
        fn fmt(self: @T, ref f: Formatter) -> Result<(), Error> {
            Display::fmt(self, ref f)
        }
    }
}

pub impl TSpanSetDebug<T, +Debug<T>, +Copy<T>, +Drop<T>> of Debug<SpanSet<T>> {
    fn fmt(self: @SpanSet<T>, ref f: Formatter) -> Result<(), Error> {
        // For a reason I don't understand, the following code doesn't compile:
        // Debug::fmt(@(*self.to_span())sc, ref f)
        let mut self = (*self).to_span();
        write!(f, "[")?;
        loop {
            match self.pop_front() {
                Option::Some(value) => {
                    if Debug::fmt(value, ref f).is_err() {
                        break Result::Err(Error {});
                    };
                    if self.is_empty() {
                        break Result::Ok(());
                    }
                    if write!(f, ", ").is_err() {
                        break Result::Err(Error {});
                    };
                },
                Option::None => { break Result::Ok(()); }
            };
        }?;
        write!(f, "]")
    }
}
