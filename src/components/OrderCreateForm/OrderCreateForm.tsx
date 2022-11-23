import './OrderCreateForm.scss';
import { Button } from 'components/Button/Button';
import { Error } from 'components/Error/Error';
import { LoaderOverlay } from 'components/LoaderOverlay/LoaderOverlay';
import { useOrder } from 'hooks/useOrder';
import { FormEvent, ReactElement, useState } from 'react';
import { OrderCreateDto } from 'dtos/OrderCreateDto';

interface Props {
  state: OrderCreateDto;
}

export const OrderCreateForm = ({state}: Props): ReactElement => {
  const [validationMessage, setValidationMessage] = useState('');
  const { createOrder } = useOrder();

  const handleSubmit = (event: FormEvent<HTMLFormElement>): void => {
    event.preventDefault();
    setValidationMessage('');
    const orderCreateDto: OrderCreateDto = { lineItems: state.lineItems };
    createOrder.mutate(orderCreateDto);
  };

  const handleErrorClear = (): void => {
    setValidationMessage('');
    createOrder.reset();
  };

  return (
    <form className="order_create_form" onSubmit={handleSubmit}>
      <LoaderOverlay isEnabled={createOrder.isLoading} />
      <p className="order_create_form__description">Create a new order</p>
      {createOrder.error ? (
        <Error onClear={handleErrorClear}>
          <li>{createOrder.error.title}</li>
        </Error>
      ) : null}
      {validationMessage ? (
        <Error onClear={handleErrorClear}>
          <li>{validationMessage}</li>
        </Error>
      ) : null}
      <Button className="order_create_form__button" type="submit">
        Create Order
      </Button>
    </form>
  );
};
