pub trait FromArray<T> {
    type Output;
    fn from_array(array: Span<T>) -> Self::Output;
}
