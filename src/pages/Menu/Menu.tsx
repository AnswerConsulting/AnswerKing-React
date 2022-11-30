import './Menu.scss';
import { LoaderOverlay } from 'components/LoaderOverlay/LoaderOverlay';
import { MenuCategories } from 'components/MenuCategories/MenuCategories';
import { MenuItems } from 'components/MenuItems/MenuItems';
import { useCategories } from 'hooks/useCategories';
import { useProducts } from 'hooks/useProducts';
import { ReactElement } from 'react';
import { Helmet } from 'react-helmet-async';
import { OrderPanel } from 'components/OrderPanel/OrderPanel';

export const MenuPage = (): ReactElement => {
  const { products } = useProducts();
  const { categories } = useCategories();

  if (!categories.data || !products.data) {
    return (
      <>
        <Helmet>
          <title>Menu - Answer King</title>
        </Helmet>
        <div className="menu">
          <LoaderOverlay isEnabled />
        </div>
      </>
    );
  }
  return (
    <>
      <Helmet>
        <title>Menu - Answer King</title>
      </Helmet>
      <div className="menu">
        <MenuCategories categories={categories.data} />

        <div className="menu__items">
          {categories.data.map((category) => (
            <MenuItems
              category={category}
              products={products.data.filter((product) => product.categories?.find((categoryId) => categoryId === category.id))}
              key={category.id}
            />
          ))}
        </div>
      </div>
      <OrderPanel />
    </>
  );
};
