---
date: 2016-08-21
authors: [nathan]
description: >
  Our new blog is built with the brand new built-in blog plugin. You can build
  a blog alongside your documentation or standalone
categories:
  - Blog
---

# Hypermedia APIs in Play! framework with the blackdoor hate library


REST APIs are all the rage. They make web services easier and simpler to use. However, most REST APIs are not fully RESTfull or "[mature](http://martinfowler.com/articles/richardsonMaturityModel.html)". This is because they typically lack one thing, [HATEOAS](https://en.wikipedia.org/wiki/HATEOAS) (Hypermedia As The Engine Of Application State). The most commonly cited reason for not creating hypermedia APIs is "it's too hard". It may indeed be hard sometimes if you're not sure what to do and the framework you're using doesn't have support built in.  
But it doesn't have to be.  
<!-- more -->
You can use the blackdoor [hate](https://github.com/blackdoor/hate) library to easily produce hypermedia APIs any time, in any framework. hate uses [HAL](http://stateless.co/hal_specification.html) (Hypermedia Application Language), which provides "a consistent and easy way to hyperlink between resources in your API". Here we will walk through using the hate library to create a hypermedia API using play framework (which has no built in support) and JPA.

We will leave these first few sections rather sparse, since great documentation on setting up this stack already exists elsewhere.

## Create play project

Following the [play framework documentation](https://www.playframework.com/documentation/2.5.x/NewApplication) let's start a new project.

```
$ activator new petstore play-java
$ cd petstore
```

## Set up our database connection

Again, following the [play framework documentation](https://www.playframework.com/documentation/2.5.x/JavaJPA) we set up our persistence. Basically we need to add dependencies to our `build.sbt`, create JPA config at `conf/META-INF/persistence.xml`, and add connection settings to `conf/application.conf`.

## Create database schema

For our petstore, we will have 3 entities: pets, items, and orders. A quick DDL for our database gives us 

```sql
CREATE TABLE pet (
	id BIGSERIAL PRIMARY KEY,
	name VARCHAR,
	type VARCHAR,
	status VARCHAR,
	photo_url VARCHAR
);

CREATE TABLE item (
	id BIGSERIAL PRIMARY KEY,
	name VARCHAR
);

CREATE TABLE orders (
	id BIGSERIAL PRIMARY KEY,
	pet_id BIGINT REFERENCES pet(id),
	item_id BIGINT REFERENCES item(id),
	quantity INT,
	order_date TIMESTAMP DEFAULT now()
);
```

I'm using PostgreSQL, but this schema should be fairly universal. Lets add a few quick rows to our database.

```sql
INSERT INTO 
	pet (name, type, status, photo_url) 
	VALUES('fido', 'dog', 'available', 'https://upload.wikimedia.org/wikipedia/commons/a/a6/Dog_anatomy_lateral_skeleton_view.jpg');
INSERT INTO item (name) VALUES ('chew toy');
INSERT INTO orders (pet_id, item_id, quantity) VALUES (1, 1, 2);
```

This migration can be found at `conf/db/migrate/migration.sql`.

## Java models

Let's make some Java model objects with JPA annotations to match our tables.

First an `Item`. This is our simplest model, something the store can order for one of the pets.

```java
@Entity
public class Item{

	@Id
	@GeneratedValue
	private long id;

	@Column
	private String name;

	// getters and setters
}
```

Next a `Pet`. Notice the pet has a URL to a photo, that will make for some nice hypermedia later.

```java
@Entity
public class Pet{

	@Id
	@GeneratedValue
	private long id;

	@Column
	private String name;

	@Column
	private String type;

	@Column
	private String status;

	@Column(name = "photo_url")
	private String photoUrl;

	//getters and setters 
}
```

Lastly an `Order`, our model with foreign keys. This is where we will really see HAL in use.

```java
@Entity
@Table(name = "orders")
public class Order{

	@Id
	@GeneratedValue
	private long id;

	@JoinColumn(name = "pet_id")
	@ManyToOne
	private Pet pet;

	@JoinColumn(name = "item_id")
	@ManyToOne
	private Item item;

	@Column
	private int quantity;

	@Column(name = "order_date")
	private Timestamp orderDate = Timestamp.from(Instant.now());

	// getters and setters
}
```

## Create routes

Let's define our route mapping at `conf/routes`. We haven't created a controller yet, but we can map our routes to controller methods which we will create later.

```
GET     /pets/:petId                controllers.ResourceController.showPet(petId: Long)
GET     /store/orders/:orderId      controllers.ResourceController.showOrder(orderId: Long)
GET     /store/inventory/:itemId    controllers.ResourceController.showItem(itemId: Long)
```

The routes file is straightforward, but it very usefull. Later we will see how we can use the play framework reverse router to build paths from this file. That means that this file will be the one definition for the location of resources, we won't have to change things anywhere else.

## Create controller

A quick play controller to access our models, querying with JPQL and serializing with play's built in jackson helper.

```java
public class ResourceController extends Controller {

    static {
    	// help our jackson a bit to give us nice timestamp strings instead of epoch
        Json.mapper().configure(SerializationFeature.WRITE_DATES_AS_TIMESTAMPS, false);
    }

    private final JPAApi jpaApi;

    @Inject
    public ResourceController(JPAApi jpaApi){
        this.jpaApi = jpaApi;
    }

    public Result showPet(long id) {
        Pet pet = (Pet) jpaApi.withTransaction(em -> 
                em.createQuery("SELECT e FROM Pet e WHERE e.id = :id")
                .setParameter("id", id)
                .getSingleResult());
        return ok(Json.toJson(pet));
    }

    public Result showOrder(long id) {
        Order order = (Order) jpaApi.withTransaction(em ->
                em.createQuery("SELECT e FROM Order e WHERE e.id = :id")
                .setParameter("id", id)
                .getSingleResult());
        return ok(Json.toJson(order));
    }

    public Result showItem(long id) {
        Item item = (Item) jpaApi.withTransaction(em -> 
                em.createQuery("SELECT e FROM Item e WHERE e.id = :id")
                .setParameter("id", id)
                .getSingleResult());
        return ok(Json.toJson(item));
    }
```

Now we have everything we need for a basic querying api. We can start our server in development mode with `activator run` and calling `GET /store/orders/1` returns us 

```json
{
  "id": 1,
  "pet": {
    "id": 1,
    "name": "fido",
    "type": "dog",
    "status": "available",
    "photoUrl": "https://upload.wikimedia.org/wikipedia/commons/a/a6/Dog_anatomy_lateral_skeleton_view.jpg"
  },
  "item": {
    "id": 1,
    "name": "chew toy"
  },
  "quantity": 2,
  "orderDate": "2016-08-22T00:14:08.442+0000"
}
```

this is all well and good, but there are a few things we might like to be different

* we don't know how to change `pet` or `item`, we would need to write some api documentation or something telling users how to take the id of those resources and build a URI with it
* in the order it's good that we can see all the details of `item` since we would rarely want to know about an order without knowing about the item being orderd, however we care less about `pet`, we still want to know what pet is associated with the order but we don't want the entire pet taking up half of our response object.
* the `photoUrl` on our pet is just a string, without human input or schema a client can't know that there is anything queryable or cachable about that field

## Add HAL

Up until now we've rushed through creation of a simple service, since all of that is rather pedestrian. Here is where we will add something slightly more interesting by using HAL to make our API fully RESTfull with HATEOAS.

Let's start in the models with our `Pet`. We will implement `black.door.hate.HalResource` which means implementing two methods, `location()` and `representationBuilder()`.

### `location()` method

`location()` is a pretty straightforward method, it returns a `URI` indicating where this particular pet can be accessed. We could simply hard-code this like `"/pets/" + id`, but if we do that then any time we change the API we would need to modify `Pet.location()`, the routes file, and any other place we were writing the location of a pet. Instead we can use play framework's reverse router to build the location of our pet from the routes file. This way our location always reflects what the API is actually listenting for. Using the reverse router our location method would look like this

```java
public URI location() {
	return URI.create(controllers.routes.ResourceController.showPet(id).url());
}
```

### `representationBuilder()` method

The `representationBuilder()` method defines exactly what we want our model to look like. We can add properties, links, and other embedded resources. The `name`, `type`, and `status` fields are clearly properties of the pet. However as we mentioned earlier, we don't want `photoUrl` as a property, so instead let's add it as a link. Likewise, rather than putting `id` as a field, we can add the location of the whole object as a link (named `self` by the HAL spec).

So now `Pet` looks like this

```java 
public class Pet implements HalResource{

	... // everything we saw earlier

	public HalRepresentation.HalRepresentationBuilder representationBuilder() {
		HalRepresentation.HalRepresentationBuilder builder = HalRepresentation.builder()
				.addProperty("name", name)
				.addProperty("type", type)
				.addProperty("status", status)
				.addLink("self", this);
		if(photoUrl != null)
			builder = builder.addLink("photo", URI.create(photoUrl));
		return builder;
	}


	public URI location() {
		return URI.create(controllers.routes.ResourceController.showPet(id).url());
	}
}
```

Giving `Item` the same treatment defining each property might feel a little tedious (after all, it looked fine serialized earlier), fortunately we don't have to. Instead we can implement `JacksonHalResource` instead of `HalResource`. Now we don't need to implement the `representationBuilder()` method, just `location()`. The library will take care of adding all the properties and `self` link for us.

```java
public class Item implements JacksonHalResource{

	...

	public URI location() {
		return URI.create(controllers.routes.ResourceController.showItem(id).url());
	}
}
```

On to our favorite model, `Order`. We can apply the same steps as our other models, but we also don't want to serialize that whole `pet` field. Instead we can add `pet` as a link, just the same as we did with `pet.photoUrl`. 

```java
public class Order implements HalResource{

	...

	public HalRepresentation.HalRepresentationBuilder representationBuilder() {
		return HalRepresentation.builder()
				.addProperty("quantity", quantity)
				.addProperty("orderDate", orderDate)
				.addLink("self", this)
				.addLink("pet", pet)
				.addEmbedded("item", item);
	}

	public URI location() {
		return URI.create(controllers.routes.ResourceController.showOrder(id).url());
	}
}
```

### `asEmbedded()`

One last quick thing we need to do is tell our controller to use the HAL format when we return our entities. Just add `.asEmbedded()` to each model before we give it to jackson.

```java
return ok(Json.toJson(order.asEmbedded()));
```

## Pretty

Now when we call `GET /store/orders/1` we get this:

```json
{
  "quantity": 2,
  "orderDate": "2016-08-22T00:14:08.442+0000",
  "_links": {
    "self": {
      "href": "/store/orders/1"
    },
    "pet": {
      "href": "/pets/1"
    }
  },
  "_embedded": {
    "item": {
      "name": "chew toy",
      "_links": {
        "self": {
          "href": "/store/inventory/1"
        }
      }
    }
  }
}
```

`pet` is no longer embedded, but we still know where to find it, `item` is clearly a related resource to the order and we know where to go if we want to modify it.  
If we go to `_links.pet.href` (If you're using postman that link should be clickable. click it. It's quite satisfying) we get 

```json
{
  "name": "fido",
  "type": "dog",
  "status": "available",
  "_links": {
    "photo": {
      "href": "https://upload.wikimedia.org/wikipedia/commons/a/a6/Dog_anatomy_lateral_skeleton_view.jpg"
    },
    "self": {
      "href": "/pets/1"
    }
  }
}
```

and `photo` is clearly a link now.

## Changing the API

Just for fun, let's say we wanted to change the mapping in our routes file from  
`GET /store/inventory/:itemId controllers.ResourceController.showItem(itemId: Long)`  
to  
`GET /store/items/:itemId     controllers.ResourceController.showItem(itemId: Long)`

We could do that, and when we call `GET /store/orders/1` again, we get

```json
{

  ...

  "_embedded": {
    "item": {
      "name": "chew toy",
      "_links": {
        "self": {
          "href": "/store/items/1"
        }
      }
    }
  }
}
```

note that item's `self` link has changed to `/store/items/1`.

Thanks for reading!

Get the source code for this post [here](https://github.com/kag0/hate-play)  
Check out more of [hate](https://github.com/blackdoor/hate), the blackdoor HATEOAS library with HAL.
