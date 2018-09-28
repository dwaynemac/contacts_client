shared_examples_for "it belongs to a contact"  do
  it { should validate_presence_of :contact_id }
  it "should return account on #contact" do
    expect(PadmaContact).to receive(:find).with(object.contact_id).and_return(PadmaContact.new(contact_id: object.contact_id))
    object.contact.should be_a(PadmaContact)
  end
end
