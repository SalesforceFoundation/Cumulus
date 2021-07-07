public inherited sharing class Money {

    private Decimal amount;
    private String curr;

    public Money(Decimal amount, String curr) {
        this.amount = amount;
        this.curr = curr;
    }

    public Decimal amount() {
        return amount;
    }
}